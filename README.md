# CryptoGost3411

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'crypto_gost3411'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install crypto_gost3411

## Usage

```ruby
require 'crypto_gost3411'
include CryptoGost3411

# one-step digest 64 bytes
data1 = 'ruby'
digest64 = Gost3411.new(64).update(data1).final
puts 'data1 digest 64 bytes:'
digest64.unpack('H*')[0].scan(/.{16}/).each{|line| puts line}

# multipart digest 32 bytes
data2 = 'gost'
ctx = Gost3411.new(32)
ctx.update(data1)
ctx.update(data2)
digest32 = ctx.final
puts 'data1+data2 digest 32 bytes:'
digest32.unpack('H*')[0].scan(/.{16}/).each{|line| puts line}
```

## Results 
```
data1 digest 64 bytes:
e03cbcfe6843fc96
6607cdd67a77de22
38549548989e63eb
9a0d9690f3e468f8
c7a555c55decfbd5
aab8b99ea945de7d
50e717313125d033
015bbb54407f0d69
data1+data2 digest 32 bytes:
c0bf500c50d02096
97fdb8629c4bc3c1
24f294bcf346c905
112f0a8e1155917e
```
 
## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/vblazhnovgit/crypto_gost3411.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
