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
      bytes = data.dup.force_encoding('BINARY')
      bytes_len = bytes.length
      # Nothing to do for empty string
      if bytes_len > 0 then
        len = @block_len + bytes_len
        if len < 64 then
          @block += bytes
          @block_len = len
        else
          index = 0
          while len >= 64			
            @block += bytes[index...(index + 64-@block_len)]
            transform(64)
            index += 64 - @block_len
            len -= 64
            @block = ''
            @block_len = 0
          end
          if len > 0 then
            @block = bytes[index...index + len]
            @block_len = len
          end
        end
      end
      return self
    end

    def final
      @block += 1.chr
      while @block.length < 64
        @block += 0.chr
      end
      # Don't increment @block_len for padding!
      transform(@block_len)
      zZ = [0,0,0,0,0,0,0,0]
      funcG(@resH, @nN, zZ)
      funcG(@resH, @sigma, zZ)
      dgst = ''
      @resH.each {|n| dgst += uint64ToUint8LE(n)}
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
  
    Two64 = 1 << 64
    Two512 = 1 << 512
    
    # Unload 64-bit number to 8-byte string
    # (little-endian, adding leading zeroes)
    def uint64ToUint8LE(n)
      [n % 0x100000000].pack("V") + [n / 0x100000000].pack("V")
    end
    
    # Unpack 8-byte (little-endian) string to 64-bit number (native-endian)
    def uint8ToUint64(bytes)
      bytes.unpack('Q*')[0]
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
        funcLPSX(tt, kk, tt)
        funcLPSX(kk, kk, C16[i])
      end
      
      (0...8).each do |i|
        h[i] ^= tt[i] ^ kk[i] ^ m[i]
      end
    end
    
    def self.add512(x, y)
      x512 = x[7]
      (1...8).each do |i|
        x512 = x512*Two64 + x[7-i]
      end  
      y512 = y[7]
      (1...8).each do |i|
        y512 = y512*Two64 + y[7-i]
      end
      r512 = (x512 + y512)%Two512
      r = []
      (0...8).each do |i|
        r << r512%Two64
        r512 = (r512-r[-1])/Two64
      end
      r
    end

    def transform(nbytes)
      count512 = [nbytes*8,0,0,0,0,0,0,0]
      mM = []
      (0...8).each do |i|
        mM << uint8ToUint64(@block[(i * 8)...(i * 8 + 8)])
      end  

      funcG(@resH, mM, @nN)
      
      @nN = self.class.add512(@nN, count512)
      @sigma = self.class.add512(@sigma, mM)
    end
    
    def self.printBytes(bytes, line_size = 16)
      bytes.unpack('H*')[0].scan(/.{1,#{line_size}}/).each{|s| puts(s)}
    end
    
    def printCtx
      puts '='*16 + ' Digest context ' + '='*16
      puts "digest_size = #{@digest_size}"
      puts "block_len = #{@block_len}"
      puts 'block:'
      self.class.printBytes(@block)
      puts 'resH:'
      (0...8).each do |i|
        printf("0x%X\n", @resH[i])
      end
      puts 'nN:'
      (0...8).each do |i|
        printf("0x%X\n", @nN[i])
      end
      puts 'sigma:'
      (0...8).each do |i|
        printf("0x%X\n", @sigma[i])
      end
      puts "="*40
    end

  end
end