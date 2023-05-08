export MicroControllerPort, setport, check

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
function Base.take!(::LineReader, data, length::Ref{Int})
    found_new_line = false
    for d in data
        if d == '\n' || d == '\r'
            found_new_line = true
        elseif found_new_line
            return String(data[1:length[]])
        end       
        length[] += 1
    end
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

function read(f::Function, p::MicroControllerPort)
    append!(p.buffer, nonblocking_read(p.sp))
    
    ptr = 1
    read_length = Ref(0)

    while ptr < length(p.buffer)
        read_data = take!(p.reader, @view(p.buffer[ptr:end]), read_length)
        read_length == 0 && continue
        f(read_data)
        ptr += read_length[]
        read_length[] = 0
    end

    deleteat!(p.buffer, 1:ptr)
    p.buffer.ptr = 1
end