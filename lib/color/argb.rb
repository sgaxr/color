# frozen_string_literal: true

require_relative 'rgb'

# An RGB colour object.
class Color::ARGB < Color::RGB
  include Color

  # The format of a DeviceRGB colour for PDF. In color-tools 2.0 this will
  # be removed from this package and added back as a modification by the
  # PDF::Writer package.
  PDF_FORMAT_STR = '%.3f %.3f %.3f %s'

  # Coerces the other Color object into RGB.
  def coerce(other)
    other.to_rgba
  end

  # Creates an ARGB colour object from the standard range 0..255.
  #
  #   Color::ARGB.new(255, 32, 64, 128)
  #   Color::ARGB.new(0xff, 0x20, 0x40, 0x80)
  def initialize(a = 255.0, r = 0, g = 0, b = 0, radix = 255.0, &block) # :yields self:
    super(r, g, b, radix)
    @a = Color.normalize(a / radix)
    block&.call(self)
  end

  # Present the colour as an RGB hex triplet.
  def hex
    a = (@a * 255).round
    a = 255 if a > 255

    r = (@r * 255).round
    r = 255 if r > 255

    g = (@g * 255).round
    g = 255 if g > 255

    b = (@b * 255).round
    b = 255 if b > 255

    '%02x%02x%02x%02x' % [a, r, g, b]
  end

  # Present the colour as an RGBA (with an optional alpha that defaults to 1)
  # HTML/CSS colour string (e.g.,"rgb(0%, 50%, 100%, 1)"). Note that this will
  # perform a #to_rgb operation using the default conversion formula.
  #
  #   Color::ARGB.by_hex('ffff0000').css_rgba
  #   => 'rgba(100.00%, 0.00%, 0.00%, 1.00)'
  #   Color::ARGB.by_hex('00ff0000').css_rgba
  #   => 'rgba(100.00%, 0.00%, 0.00%, 0)'
  def css_rgba
    'rgba(%3.2f%%, %3.2f%%, %3.2f%%, %3.2f)' % [red_p, green_p, blue_p, @a]
  end

  def to_rgb(ignored = nil)
    self
  end

  # Mix the RGB hue with White so that the RGB hue is the specified
  # percentage of the resulting colour. Strictly speaking, this isn't a
  # darken_by operation.
  def lighten_by(percent)
    mix_with(White, percent)
  end

  # Mix the RGB hue with Black so that the RGB hue is the specified
  # percentage of the resulting colour. Strictly speaking, this isn't a
  # darken_by operation.
  def darken_by(percent)
    mix_with(Black, percent)
  end

  # Mix the mask colour (which must be an RGB object) with the current
  # colour at the stated opacity percentage (0..100).
  def mix_with(mask, opacity)
    opacity /= 100.0
    rgb = dup

    rgb.r = (@r * opacity) + (mask.r * (1 - opacity))
    rgb.g = (@g * opacity) + (mask.g * (1 - opacity))
    rgb.b = (@b * opacity) + (mask.b * (1 - opacity))

    rgb
  end

  # Returns the alpha component of the colour in the normal 0 .. 255 range.
  def alpha
    @a * 255.0
  end

  # Returns the alpha component of the colour as a percentage.
  def alpha_p
    @a * 100.0
  end

  # Returns the alpha component of the colour as a fraction in the range 0.0
  attr_reader :a

  # Sets the alpha component of the colour in the normal 0 .. 255 range.
  def alpha=(aa)
    @a = Color.normalize(aa / 255.0)
  end

  # Sets the alpha component of the colour as a percentage.
  def alpha_p=(aa)
    @a = Color.normalize(aa / 100.0)
  end

  # Sets the alpha component of the colour as a fraction in the range 0.0 ..
  # 1.0.
  def a=(aa)
    @a = Color.normalize(aa)
  end

  # Adds another colour to the current colour. The other colour will be
  # converted to RGB before addition. This conversion depends upon a #to_rgb
  # method on the other colour.
  #
  # The addition is done using the RGB Accessor methods to ensure a valid
  # colour in the result.
  def +(other)
    self.class.from_fraction(r + other.r, g + other.g, b + other.b, a + other.a)
  end

  # Subtracts another colour to the current colour. The other colour will be
  # converted to RGB before subtraction. This conversion depends upon a
  # #to_rgb method on the other colour.
  #
  # The subtraction is done using the RGB Accessor methods to ensure a valid
  # colour in the result.
  def -(other)
    self + -other
  end

  # Retrieve the maxmum RGB value from the current colour as a GrayScale
  # colour
  def max_rgb_as_grayscale
    Color::GrayScale.from_fraction([@r, @g, @b].max)
  end
  alias max_rgb_as_greyscale max_rgb_as_grayscale

  def inspect
    "ARGB [#{html}]"
  end

  def to_a
    [a, r, g, b]
  end

  # Numerically negate the color. This results in a color that is only
  # usable for subtraction.
  def -@
    rgb = dup
    rgb.instance_variable_set(:@a, -rgb.a)
    rgb.instance_variable_set(:@r, -rgb.r)
    rgb.instance_variable_set(:@g, -rgb.g)
    rgb.instance_variable_set(:@b, -rgb.b)
    rgb
  end
end

class << Color::ARGB
  # Creates an RGB colour object from percentages 0..100.
  #
  #   Color::RGB.from_percentage(10, 20, 30)
  def from_percentage(a = 0, r = 0, g = 0, b = 0, &block)
    new(a, r, g, b, 100.0, &block)
  end

  # Creates an RGB colour object from fractional values 0..1.
  #
  #   Color::RGB.from_fraction(.3, .2, .1)
  def from_fraction(a = 0.0, r = 0.0, g = 0.0, b = 0.0, &block)
    new(a, r, g, b, 1.0, &block)
  end

  # Creates an RGB colour object from a grayscale fractional value 0..1.
  def from_grayscale_fraction(l = 0.0, &block)
    new(1, l, l, l, &block)
  end
  alias_method :from_greyscale_fraction, :from_grayscale_fraction

  # Creates an RGB colour object from an HTML colour descriptor (e.g.,
  # <tt>"fed"</tt> or <tt>"#cabbed;"</tt>.
  #
  #   Color::RGB.from_html("fed")
  #   Color::RGB.from_html("#fed")
  #   Color::RGB.from_html("#cabbed")
  #   Color::RGB.from_html("cabbed")
  def from_html(html_colour, &block)
    # When we can move to 1.9+ only, this will be \h
    h = html_colour.scan(/[0-9a-f]/i)
    case h.size
    when 3
      new(1, *h.map { |v| (v * 2).to_i(16) }, &block)
    when 6
      new(1, *h.each_slice(2).map { |v| v.join.to_i(16) }, &block)
    when 8
      new(*h.each_slice(2).map { |v| v.join.to_i(16) }, &block)
    else
      raise ArgumentError, 'Not a supported HTML colour type.'
    end
  end

  # Find or create a colour by an HTML hex code. This differs from the
  # #from_html method in that if the colour code matches a named colour,
  # the existing colour will be returned.
  #
  #     Color::RGB.by_hex('ff0000').name # => 'red'
  #     Color::RGB.by_hex('ff0001').name # => nil
  #
  # If a block is provided, the value that is returned by the block will
  # be returned instead of the exception caused by an error in providing a
  # correct hex format.
  def by_hex(hex, &block)
    __by_hex.fetch(html_hexify(hex)) { from_html(hex) }
  rescue StandardError
    if block
      block.call
    else
      raise
    end
  end

  # Return a colour as identified by the colour name.
  def by_name(name, &block)
    __by_name.fetch(name.to_s.downcase, &block)
  end

  # Return a colour as identified by the colour name, or by hex.
  def by_css(name_or_hex, &block)
    by_name(name_or_hex) { by_hex(name_or_hex, &block) }
  end

  # Extract named or hex colours from the provided text.
  def extract_colors(text, mode = :both)
    text  = text.downcase
    regex = case mode
            when :name
              Regexp.union(__by_name.keys)
            when :hex
              Regexp.union(__by_hex.keys)
            when :both
              Regexp.union(__by_hex.keys + __by_name.keys)
            end

    text.scan(regex).map do |match|
      case mode
      when :name
        by_name(match)
      when :hex
        by_hex(match)
      when :both
        by_css(match)
      end
    end
  end
end

class << Color::ARGB
  private

  def __named_color(mod, rgb, *names)
    used = names - mod.constants.map(&:to_sym)
    if used.length < names.length
      raise ArgumentError, "#{names.join(', ')} already defined in #{mod}"
    end

    names.each { |n| mod.const_set(n, rgb) }

    rgb.names = names
    rgb.names.each { |n| __by_name[n] = rgb }
    __by_hex[rgb.hex] = rgb
    rgb.freeze
  end

  def __by_hex
    @__by_hex ||= {}
  end

  def __by_name
    @__by_name ||= {}
  end

  def html_hexify(hex)
    # When we can move to 1.9+ only, this will be \h
    h = hex.to_s.downcase.scan(/[0-9a-f]/)
    case h.size
    when 3
      h.map { |v| (v * 2) }.join
    when 6
      h.join
    when 8
      h.join
    else
      raise ArgumentError, 'Not a supported HTML colour type.'
    end
  end
end

require 'color/rgb/colors'
