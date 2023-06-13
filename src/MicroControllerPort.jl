export MicroControllerPort, setport, readport, RegexReader, DelimitedReader, PortsObservable, FixedLengthReader, readn, peekn

abstract type IOReader end

Base.take!(::IOReader, data::IOBuffer) = ()

mutable struct MicroControllerPort
    name
    sp
    baud::Integer
    mode::SPMode
    ndatabits::Integer
    parity::SPParity
    nstopbits::Integer
    buffer::IOBuffer
    reader
    connection::Observable{Bool}

    function MicroControllerPort(name, baud, reader; mode=SP_MODE_READ_WRITE, ndatabits=8, parity=SP_PARITY_NONE, nstopbits=1)
        return new(name, nothing, baud, mode, ndatabits, parity, nstopbits, IOBuffer(), reader, Observable(false; ignore_equal_values=true))
    end
        
    Observables.on(cb::Function, p::MicroControllerPort; update=false) = on(cb, p.connection; update=update)
    Base.setindex!(p::MicroControllerPort, port) = setport(p, port)
end

struct RegexReader <: IOReader
    rgx::Regex 
    length_range::AbstractRange
end
DelimitedReader(delimeter = "[\n\r]", length_range = 1:1000) = RegexReader(Regex("(.*)(?:$delimeter)"), length_range)
function Base.take!(regex::RegexReader, io::IOBuffer)
    s = read(io, String)
    m = match(regex.rgx, s)
    if m !== nothing
        str = m[1]                                                   #Match with the payload
        io.ptr = length(m.match) + 1
        return length(str) in regex.length_range ? str : nothing     #Set Range Limit
    end
    io.ptr = 1
    return nothing
end

Base.close(p::MicroControllerPort) = isopen(p) && (LibSerialPort.close(p.sp); p.sp=nothing; p.connection[] = false)
Base.isopen(p::MicroControllerPort) = p.sp !== nothing && LibSerialPort.isopen(p.sp)
Base.write(p::MicroControllerPort, v::UInt8) = LibSerialPort.write(p.sp, v)
Base.print(io::IO, p::MicroControllerPort) = print(io, "Port[$(p.name), baud=$(p.baud), open=$(isopen(p))]")
function setport(p::MicroControllerPort, name)
    close(p)
    (name == "" || name === nothing) && return false
    p.sp = LibSerialPort.open(name, p.baud; mode=p.mode, ndatabits=p.ndatabits, parity=p.parity, nstopbits=p.nstopbits)
    p.connection[] = true
    return true
end

function readport(f::Function, p::MicroControllerPort)
    if !isopen(p)
        close(p)
        return
    end
    LibSerialPort.bytesavailable(p.sp) > 0 || return
   
    try
        p.buffer.ptr = p.buffer.size + 1
        write(p.buffer, nonblocking_read(p.sp))
    catch e
        showerror(e)
        close(p)
    end
    
    while p.buffer.size > 0
        p.buffer.ptr = 1
        mark(p.buffer)
        read_data = take!(p.reader, p.buffer)
        read_data === nothing || f(read_data)
        bytes_read = p.buffer.ptr - 1
        bytes_read > 0 && deleteat!(p.buffer.data, 1:bytes_read)
        p.buffer.size -= bytes_read
        read_data === nothing && break
    end
end


const PortsObservable = Observable(Set{String}())

function init_ports()
    global __portlistener__
    __portlistener__ = Timer(0; interval=2) do t
        nl = Set(get_port_list())
        issetequal(PortsObservable[], nl) && return
        PortsObservable[] = nl
    end
end

struct FixedLengthReader <: IOReader length::Integer end
function Base.take!(r::FixedLengthReader, io::IOBuffer)
    if bytesavailable(io) >= r.length
        data = Array{UInt8}(undef, r.length)
        readbytes!(io, data, r.length)
        return data
    end
    return nothing
end


const MAGIC_NUMBER::UInt32 = 0xDEADBEEF
const TAIL_MAGIC_NUMBER::UInt8 = 0xEE

struct SimplePacketHeader
    Size::UInt8 
    Type::UInt8 
    Num::UInt8 

    SimplePacketHeader(s, t, n) = new(s, t, n)
    Base.read(io::IO, ::Type{SimplePacketHeader}) = SimplePacketHeader(read(io, UInt8), read(io, UInt8), read(io, UInt8))
end

mutable struct SimpleConnection <: JuliaSAILGUI.IOReader
    port::MicroControllerPort
    packet_loss::UInt16
    last_packet_rx_count::UInt8 
    packet_count::UInt8 
    onPacketCorrupted::Function

    function SimpleConnection(port::MicroControllerPort, onPacketCorrupted = (h) -> ())
        c = new(port, 0, 0, 0, onPacketCorrupted)
        port.reader = c
        c
    end
end

function Base.write(s::SimpleConnection, type::Integer, x...)
    write(x::T) where T <: Number = write(s.port, hton(x)) 
    write(x) = write(s.port, x) 
    write(MAGIC_NUMBER)
    write(SimplePacketHeader(UInt8(sum(sizeof, x)), UInt8(type), UInt8(s.packet_count)))
    foreach(write, x)
    write(TAIL_MAGIC_NUMBER)
    s.packet_count += 1
end

readn(io::IO, ::Type{T}) where T <: Number = ntoh(read(io, T))
peekn(io::IO, ::Type{T}) where T <: Number = ntoh(peek(io, T))
peekn(io::IO, T::Type) = peek(io, T)
readn(io::IO, T::Type) = read(io, T)
readn(io::IO, Types::Type...) = [readn(io, T) for T in Types]
readn(io::IO, T::Type, count::Integer) = [readn(io, T) for i in 1:count]

function Base.take!(r::SimpleConnection, io::IOBuffer)
    head::UInt32 = 0
    canread(s::Integer) = bytesavailable(io) >= s
    canread(::Type{T}) where T = canread(sizeof(T))
    canread(x) = canread(sizeof(typeof(x)))

    while canread(UInt32) && (head = peekn(io, UInt32)) != MAGIC_NUMBER
        io.ptr += 1                             
    end

    mark(io)                                                      #Mark after discardable data
    
    if canread(sizeof(MAGIC_NUMBER) + sizeof(SimplePacketHeader)) && (readn(io, UInt32) == MAGIC_NUMBER)
        header = read(io, SimplePacketHeader)
        if canread(header.Size + 1)
            base_pos = io.ptr
            io.ptr += header.Size
            if read(io, UInt8) == TAIL_MAGIC_NUMBER               #Peek ahead to make sure tail is okay
                if header.Num < r.last_packet_rx_count            #Rollover
                    r.packet_loss += (typemax(UInt8) - r.last_packet_rx_count) + header.Num
                else
                    r.packet_loss += header.Num - r.last_packet_rx_count
                end
                r.last_packet_rx_count = header.Num
                payload = IOBuffer(@view(io.data[base_pos:(base_pos + header.Size)]))
                return (header, payload)
            else
                r.packet_loss += 1
                r.onPacketCorrupted(header)                      #Dont reset since its corrupted. Throw the memory away
                return nothing
            end
        end
    end

    io.ptr = io.mark
    return nothing
end