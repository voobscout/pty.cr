class Pty
  class IO < IO::FileDescriptor
    getter temp_closed = Atomic(Int16).new 0

    def self.new(path : Path | String)
      fd = Crystal::System::File.open(path.to_s, "r+", 0o600)
      super(fd)
    end

    protected def unbuffered_read(slice : Bytes)
      # Replace evented_read with direct LibC.read call and proper error handling
      bytes_read = LibC.read(fd, slice, slice.size)
      
      if bytes_read == -1
        if Errno.value == Errno::EAGAIN || Errno.value == Errno::EWOULDBLOCK
          # Wait until the file descriptor is readable
          wait_readable
          return unbuffered_read(slice)
        elsif Errno.value == Errno::EBADF || Errno.value == Errno::EIO
          return 0
        else
          raise IO::Error.from_errno("Error reading file")
        end
      end
      
      bytes_read
    end

    # Wait until the file descriptor is readable
    private def wait_readable
      Crystal::System::FileDescriptor.wait_readable(fd)
      true
    rescue ex : IO::Error
      if ex.errno == Errno::EBADF || ex.errno == Errno::EIO
        false
      else
        raise ex
      end
    end

    # Wait until the file descriptor is writable
    private def wait_writable
      Crystal::System::FileDescriptor.wait_writable(fd)
      true
    rescue ex : IO::Error
      if ex.errno == Errno::EBADF || ex.errno == Errno::EIO
        false
      else
        raise ex
      end
    end

    def tcflush : Nil
      r = C.tcflush(fd, C::TCIOFLUSH)
      raise Error.from_errno("tcflush") unless r == 0
    end
  end
end
