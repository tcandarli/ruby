# frozen_string_literal: true
# Copyright © 2018 Martin J. Dürst (duerst@it.aoyama.ac.jp)

require "test/unit"

class BreakTest
  attr_reader :string, :comment, :filename, :line_number, :type, :shortname

  def initialize (filename, line_number, data, comment='')
    @filename = filename
    @line_number = line_number
    @comment = comment
    if filename=='emoji-test'
      codes, @type = data.split(/\s*;\s*/)
      @shortname = ''
    else
      codes, @type, @shortname = data.split(/\s*;\s*/)
    end
    @string = codes.split(/\s+/)
                   .map do |ch|
                          c = ch.to_i(16)
                           # eliminate cases with surrogates
                          # raise ArgumentError if 0xD800 <= c and c <= 0xDFFF
                          c.chr('UTF-8')
                        end.join
    raise ArgumentError if data.match? /genie/ or comment.match? /genie/
    raise ArgumentError if data.match? /zombie/ or comment.match? /zombie/
    raise ArgumentError if data.match? /wrestling/ or comment.match? /wrestling/
  end
end

class TestEmojiBreaks < Test::Unit::TestCase
  EMOJI_DATA_FILES = %w[emoji-sequences emoji-test emoji-variation-sequences emoji-zwj-sequences]
  EMOJI_VERSION = '5.0' # hard-coded, should be replaced by
                        # RbConfig::CONFIG['UNICODE_EMOJI_VERSION'] or so, see feature #15341
  EMOJI_DATA_PATH = File.expand_path("../../../enc/unicode/data/emoji/#{EMOJI_VERSION}", __dir__)

  def self.expand_filename(basename)
    File.expand_path("#{EMOJI_DATA_PATH}/#{basename}.txt", __dir__)
  end

  def self.data_files_available?
    EMOJI_DATA_FILES.all? do |f|
      File.exist?(expand_filename(f))
    end
  end

  def test_data_files_available
    unless TestEmojiBreaks.data_files_available?
      skip "Emoji data files not available in #{EMOJI_DATA_PATH}."
    end
  end
end

TestEmojiBreaks.data_files_available? and  class TestEmojiBreaks
  def read_data
    tests = []
    EMOJI_DATA_FILES.each do |filename|
      version_mismatch = true
      file_tests = []
      IO.foreach(TestEmojiBreaks.expand_filename(filename), encoding: Encoding::UTF_8) do |line|
        line.chomp!
        raise "File Name Mismatch"  if $.==1 and not line=="# #{filename}.txt"
        version_mismatch = false  if line=="# Version: #{EMOJI_VERSION}"
        next  if /\A(#|\z)/.match? line
        file_tests << BreakTest.new(filename, $., *line.split('#')) rescue 'whatever'
      end
      raise "File Version Mismatch"  if version_mismatch
      tests += file_tests
    end
    tests
  end

  def all_tests
    @@tests ||= read_data
  rescue Errno::ENOENT
    @@tests ||= []
  end

  def test_single_emoji
    all_tests.each do |test|
      expected = [test.string]
      actual = test.string.each_grapheme_cluster.to_a
      assert_equal expected, actual,
        "file: #{test.filename}, line #{test.line_number}, expected '#{expected}', " +
        "but got '#{actual}', type: #{test.type}, shortname: #{test.shortname}, comment: #{test.comment}"
    end
  end

  def test_embedded_emoji
    all_tests.each do |test|
      expected = ["A", test.string, "Z"]
      actual = "A#{test.string}Z".each_grapheme_cluster.to_a
      assert_equal expected, actual,
        "file: #{test.filename}, line #{test.line_number}, expected '#{expected}', " +
        "but got '#{actual}', type: #{test.type}, shortname: #{test.shortname}, comment: #{test.comment}"
    end
  end

  # test some pseodorandom combinations of emoji
  def test_mixed_emoji
    srand 0
    length = all_tests.length
    step = 503 # use a prime number
    all_tests.each do |test1|
      start = rand step
      start.step(by: step, to: length-1) do |t2|
        test2 = all_tests[t2]
        expected = [test1.string, test2.string]
        actual = (test1.string+test2.string).each_grapheme_cluster.to_a
        assert_equal expected, actual,
          "file: #{test1.filename}, line #{test1.line_number}, expected '#{expected}', " +
          "but got '#{actual}', type: #{test1.type}, shortname: #{test1.shortname}, comment: #{test1.comment}"
      end
    end
  end
end
