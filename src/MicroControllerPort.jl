export MicroControllerPort, setport, readport, RegexReader, DelimitedReader, PortsObservable

pass() = ()

abstract type IOReader end

Base.take!(::IOReader, data, length::Ref{Int}) = data

mutable struct MicroControllerPort
    name
    sp
    baud::Integer
    buffer::Array{UInt8}
    reader
    on_disconnect 

    MicroControllerPort(name, baud, reader; on_disconnect = pass) = new(name, nothing, baud, UInt8[], reader, on_disconnect)
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

Base.close(p::MicroControllerPort) = isopen(p) && (LibSerialPort.close(p.sp); p.sp=nothing; p.on_disconnect(); println("$p Disconnected!"))
Base.isopen(p::MicroControllerPort) = p.sp !== nothing && LibSerialPort.isopen(p.sp)
Base.write(p::MicroControllerPort, v::UInt8) = LibSerialPort.write(p.sp, v)
Base.print(io::IO, p::MicroControllerPort) = print(io, "Port[$(p.name), baud=$(p.baud), open=$(isopen(p))]")
function setport(p::MicroControllerPort, name)
    close(p)
    (name == "" || name === nothing) && return false
    p.sp = LibSerialPort.open(name, p.baud)
    println("$p Connected!")
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