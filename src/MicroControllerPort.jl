export MicroControllerPort, setport, readport, RegexReader, DelimitedReader, PortsObservable

abstract type IOReader end

Base.take!(::IOReader, data, length::Ref{Int}) = data

mutable struct MicroControllerPort
    name
    sp
    baud::Integer
    mode::SPMode
    ndatabits::Integer
    parity::SPParity
    nstopbits::Integer
    buffer::Array{UInt8}
    reader
    connection::Observable{Bool}

    MicroControllerPort(name, baud, reader; mode=SP_MODE_READ_WRITE, ndatabits=8, parity=SP_PARITY_NONE, nstopbits=1) = 
        new(name, nothing, baud, mode, ndatabits, parity, nstopbits, UInt8[], reader, Observable(false))
    Observables.on(cb::Function, p::MicroControllerPort; update=false) = on(cb, p.connection; update=update)
end

struct RegexReader 
    rgx::Regex 
    length_range::AbstractRange
end
DelimitedReader(delimeter = "[\n\r]", length_range = 1:1000) = RegexReader(Regex("(.*)(?:$delimeter)"), length_range)
function Base.take!(regex::RegexReader, data, len::Ref{Int})
    m = match(regex.rgx, String(data))
    if m !== nothing
        str = m[1]                                      #Match with the payload
        len[] = length(m.match)                         #Strip the termininating lines
        return length(str) in regex.length_range ? str : nothing     #Set Range Limit
    end
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
    p.connection = true[]
    return true
end

function readport(f::Function, p::MicroControllerPort)
    if !isopen(p)
        close(p)
        return
    end

    LibSerialPort.bytesavailable(p.sp) > 0 || return
    
    append!(p.buffer, read(p.sp))
    ptr = 1
    read_length = Ref(0)

    while ptr <= length(p.buffer)
        read_data = take!(p.reader, @view(p.buffer[ptr:end]), read_length)
        ptr += read_length[]
        read_data === nothing && break
        f(read_data)
        read_length[] = 0
    end

    ptr != 1 && deleteat!(p.buffer, 1:(ptr - 1))
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