export MicroControllerPort, setport, check, readport, LineReader

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

    MicroControllerPort(name, baud, reader; on_disconnect=pass) = new(name, nothing, baud, UInt8[], reader, on_disconnect)
end

struct LineReader end
function Base.take!(::LineReader, data, len::Ref{Int})
    m = match(r"^([^\n\r]+)[\n\r]+", String(data))
    if m !== nothing
        data = m[1]
        len[] = length(data)
        return data
    end
    return nothing
end

Base.close(p::MicroControllerPort) = isopen(p) && (LibSerialPort.close(p.sp); p.sp=nothing; p.on_disconnect(); println("$p Disconnected!"))
Base.isopen(p::MicroControllerPort) = p.sp !== nothing && LibSerialPort.isopen(p.sp)
function check(p::MicroControllerPort)
    isopen(p) && return true
    p.sp === nothing || close(p)
    return false
end

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
    append!(p.buffer, nonblocking_read(p.sp))
    
    ptr = 1
    read_length = Ref(0)

    while ptr < length(p.buffer)
        read_data = take!(p.reader, @view(p.buffer[ptr:end]), read_length)
        read_data === nothing && break
        f(read_data)
        ptr += read_length[]
        read_length[] = 0
    end

    ptr != 1 && deleteat!(p.buffer, 1:(ptr - 1))
end