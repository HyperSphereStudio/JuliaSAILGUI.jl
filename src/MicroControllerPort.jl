export MicroControllerPort, setport, readport, RegexReader, DelimitedReader, PortsObservable, FixedLengthReader, readn

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

    MicroControllerPort(name, baud, reader; mode=SP_MODE_READ_WRITE, ndatabits=8, parity=SP_PARITY_NONE, nstopbits=1) = 
        new(name, nothing, baud, mode, ndatabits, parity, nstopbits, IOBuffer(seekable=false), reader, Observable(false; ignore_equal_values=true))
    Observables.on(cb::Function, p::MicroControllerPort; update=false) = on(cb, p.connection; update=update)
end

struct RegexReader <: IOReader
    rgx::Regex 
    length_range::AbstractRange
end
DelimitedReader(delimeter = "[\n\r]", length_range = 1:1000) = RegexReader(Regex("(.*)(?:$delimeter)"), length_range)
function Base.take!(regex::RegexReader, io::IOBuffer)
    mark(io)
    m = match(regex.rgx, read(io, String))
    if m !== nothing
        str = m[1]                                                   #Match with the payload
        reset(io)
        io.ptr += length(m.match)
        return length(str) in regex.length_range ? str : nothing     #Set Range Limit
    end
    reset(io)
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
    write(p.buffer, read(p.sp))

    while !eof(p.buffer)
        take!(p.reader, p.buffer)
        read_data === nothing && break
        f(read_data)
    end

    unmark(p.buffer)
    Base.compact(p.buffer)
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
const HeartBeatType::UInt8 = 255

struct SimplePacketHeader
    Size::UInt8 
    Type::UInt8 
    Num::UInt8 
end

mutable struct SimpleConnection <: IOReader
    rxTimer::HTimer
    txTimer::HTimer
    port::MicroControllerPort
    packet_loss::UInt16
    last_packet_rx_count::UInt8 
    packet_count::UInt8 
    onPacketCorrupted::Function

    function SimpleConnection(port::MicroControllerPort, heartbeat_interval::Integer, onPacketCorrupted = (h) -> ())
        rxTimer = HTimer(0, heartbeat_interval; start=false) do t
            port.connection[] = false
        end

        r = new(rxTimer, txTimer, port, 0, 0, 0, onPacketCorrupted)

        txTimer = HTimer(0, heartbeat_interval ÷ 2; start=false) do t
            write(r, HeartBeatType)
        end

        on(c -> begin
                    if c
                       resume(r.rxTimer)
                       resume(r.txTimer)
                    else
                       pause(r.rxTimer)
                       pause(r.txTimer)
                    end   
                end, port; update=true)
        return r
    end
    
end

function Base.write(s::SimpleConnection, type::Integer, x...)
    write(x::T) where T <: Number = write(s.port, hton(x)) 
    write(x) = write(s.port, x) 
    write(MAGIC_NUMBER)
    write(SimplePacketHeader(UInt8(sum(sizeof, x)), UInt8(type), s.packet_count))
    foreach(write, x)
    write(TAIL_MAGIC_NUMBER)
    s.packet_count += 1
end
readn(io::IO, ::Type{T}) where T <: Number = ntoh(read(io, t))
readn(io::IO, ::Type) = read(io, t)

function Base.take!(r::SimpleConnection, io::IOBuffer)
    head::UInt32 = 0
    canread(s::Integer) = bytesavailable(io) >= s
    canread(::Type{T}) where T = canread(sizeof(T))
    canread(x) = canread(sizeof(typeof(x)))

    bytesavailable(io) > 0 && reset(r.rxTimer)

    while canread(UInt32) && (head = peek(io, UInt32)) != MAGIC_NUMBER
        io.ptr += 1                             
    end

    mark(io)                                                      #Mark after discardable data
    
    if canread(sizeof(MAGIC_NUMBER) + sizeof(SimplePacketHeader)) && (read(io, UInt32) == MAGIC_NUMBER)
        header = read(io, SimplePacketHeader)
        if canread(header.Size + 1)
            unmark(io)                                            #Everything past this point should be readable or throw it away, so no longer need mark
            io.ptr += header.Size
            if read(io, UInt8) == TAIL_MAGIC_NUMBER               #Peek ahead to make sure tail is okay
                io.ptr -= header.Size + 1
                if header.Num < r.last_packet_rx_count            #Rollover
                    packet_loss += (typemax(UInt8) - r.last_packet_rx_count) + header.Num
                else
                    packet_loss += header.Num - r.last_packet_rx_count
                end
                r.last_packet_rx_count = header.Num
                header.Type != HeartBeatType && (return (header, io))
            else
                packet_loss += 1
                r.onPacketCorrupted(header)                      #Dont reset since its corrupted. Throw the memory away
                return nothing
            end
        end
    end

    reset(io)
    return nothing
end