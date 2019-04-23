module CryptoGost3411
  class Gost3411

    def initialize(digest_size=64)
      if digest_size != 32 then 	
        digest_size = 64
      end
      @digest_size = digest_size;
      # @resH - [8] uint64
      if @digest_size == 64 then
        @resH = [0,0,0,0,0,0,0,0]
      else
        e = uint8ToUint64("\x01" * 8)
        @resH = [e,e,e,e,e,e,e,e]
      end
      # [8] uint64
      @sigma = [0,0,0,0,0,0,0,0]
      # [8] uint64
      @nN = [0,0,0,0,0,0,0,0]
      # byte string
      @block = ''
      @block_len = 0
    end

    def update(data)
      bytes = data.force_encoding('BINARY')
      bytes_len = bytes.length
      # Nothing to do for empty string
      if bytes_len > 0 then
        len = 0
        len = @block_len + bytes_len;
        if len < 64 then
          @block += bytes
          @block_len = len
        else
          index = 0
          while len >= 64			
            @block += bytes[index...(index + 64-@block_len)]
            transform(512)
            index += 64 - @block_len
            len -= 64
            @block = ''
            @block_len = 0
          end
          if len > 0 then
            @block = bytes[index...index + len]
            @block_len = len;
          end
        end
      end
      return self
    end

    def final
      @block += "\x01"   
      while @block.length < 64
        @block += "\x00"
      end
      # Don't increment @block_len for padding!
      
      transform(@block_len * 8)

      zZ = [0,0,0,0,0,0,0,0]
      funcG(@resH, @nN, zZ);
      funcG(@resH, @sigma, zZ);

      (0...8).each do |i|
        @resH[i] = bswap64(@resH[i])
      end
      
      dgst = ''
      @resH.each {|n| dgst += uint64ToUint8(n)}
      if @digest_size == 32
        dgst = dgst[32..-1]
      end  

      return dgst
    end

    def digest(data)
      update(data)
      dgst = final
    end
    
    private
    
    # 's' stands for native-endian byte order but 'n' stands for network (big-endian) byte order
    BigEndian = [1].pack('s') == [1].pack('n')

    # Unload 64-bit number to 8-byte string
    # (big-endian, adding leading zeroes)
    def uint64ToUint8BE(n)
      str = n.to_s(16) # big-endian
      len = str.length
      # add leading zeroes
      str.insert(0, '0'*(16 - len)) if len < 16
      # To byte string
      bytes = [str].pack('H*')
    end 
    
    # Unload 64-bit number to 8-byte string
    # (native-endian, adding leading zeroes)
    def uint64ToUint8(n)
      bytes = uint64ToUint8BE(n)    
      bytes.reverse! unless BigEndian   
      return bytes
    end
    
    # Unpacks 8-byte string to 64-bit number 
    # (native-endian)
    def uint8ToUint64(bytes)
      bytes.unpack('Q*')[0]
    end
    
    # Rotate the 32 bit unsigned integer x by n bits left/right
    def rol32(x, n)
      ( (x << (n&(32-1))) | (x >> ((32-n)&(32-1)))) & 0xFFFFFFFF
    end
    
    def ror32(x, n)
      ((x >> (n&(32-1))) | (x << ((32 - n)&(32-1)))) & 0xFFFFFFFF
    end
     
    # Byte swap for 32-bit and 64-bit integers
    def bswap32(x)
      if BigEndian
        return ((rol32(x, 8) & 0x00ff00ff) | (ror32(x, 8) & 0xff00ff00))
      else
        return x
      end  
    end
    
    def bswap64(x)
      if BigEndian
        return (bswap32(x%0x100000000) << 32) | (bswap32((x >> 32)&0xFFFFFFFF))
      else
        return x
      end  
    end

    def bufGetLE64(buf)
      return (buf[7].ord << 56) | (buf[6].ord << 48) | 
             (buf[5].ord << 40) | (buf[4].ord << 32) | 
             (buf[3].ord << 24) | (buf[2].ord << 16) | 
             (buf[1].ord << 8) | buf[0].ord
    end

    # out, temp - arrays[8]
    def strido(out, temp, i)   
      t  = Gost3411Table[0][(temp[0] >> (i * 8)) & 0xff]
      (1...8).each{|j| t ^= Gost3411Table[j][(temp[j] >> (i * 8)) & 0xff]}    
      out[i] = t 
    end  

    # out, a, b, temp - arrays[8]
    def funcLPSX(out, a, b)
      temp = [0,0,0,0,0,0,0,0]
      (0...a.length).each{|i| temp[i] = a[i] ^ b[i]}
      (0...temp.length).each{|i| strido(out, temp, i)}
    end

    # h, m, n - arrays[8] of 64-bit numbers
    def funcG(h, m, n)
      kk = [0,0,0,0,0,0,0,0]
      tt = [0,0,0,0,0,0,0,0]
      funcLPSX(kk, h, n)
      funcLPSX(tt, kk, m)
      funcLPSX(kk, kk, C16[0])
      (1...12).each do |i|
        funcLPSX(tt, kk, tt);
        funcLPSX(kk, kk, C16[i]);
      end
      
      (0...8).each do |i|
        h[i] ^= tt[i] ^ kk[i] ^ m[i]
      end
    end

    def transform(nbits)
      mM = []
      (0...8).each do |i|
        mM << bufGetLE64(@block[(i * 8)...(i * 8 + 8)])
      end  

      funcG(@resH, mM, @nN)
      ll = @nN[0]
      @nN[0] += nbits
      # truncate overload
      @nN[0] &= 0xFFFFFFFFFFFFFFFF
      if @nN[0] < ll then
        # overload
        (1...8).each do |i|
          @nN[i] += 1
          break if @nN[i] != 0 
        end
      end

      @sigma[0] += mM[0]
      # truncate overload
      @sigma[0] &= 0xFFFFFFFFFFFFFFFF
      (1...8).each do |i|
        if @sigma[i-1] < mM[i-1] then
          @sigma[i] += (mM[i] + 1)
        else
          @sigma[i] += mM[i]
        end  
        # truncate overload
        @sigma[i] &= 0xFFFFFFFFFFFFFFFF
      end 
    end
  end
end