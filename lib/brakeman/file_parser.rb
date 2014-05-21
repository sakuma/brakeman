Thread.abort_on_exception = true

module Brakeman
  ASTFile = Struct.new(:path, :ast)

  # This class handles reading and parsing files.
  class FileParser
    attr_reader :file_list

    def initialize tracker, app_tree
      @tracker = tracker
      @app_tree = app_tree
      @file_list = {}
    end

    def parse_files list, type
      read_files list, type do |path, contents|
        ast = parse_ruby path, contents
        if ast
          ASTFile.new(path, ast)
        end
      end
    end

    def read_files list, type
      @file_list[type] ||= []

      list.each do |path|
        result = yield path, read_path(path)
        if result
          @file_list[type] << result
        end
      end
    end

    def parse_ruby input, path
      begin
        RubyParser.new.parse path, input
      rescue Racc::ParseError => e
        @tracker.error e, "Could not parse #{path}. There is probably a typo in the file. Test it with 'ruby -c #{path}'"
        nil
      rescue => e
        @tracker.error e.exception(e.message + "\nWhile processing #{path}"), e.backtrace
        nil
      end
    end

    def read_path path
      @app_tree.read_path path
    end
  end

  # This class handles reading and parsing files in parallel.
  class ParallelFileParser < FileParser
    def initialize tracker, app_tree, num_threads = 5
      super tracker, app_tree

      @file_queue = Queue.new
      @contents_queue = Queue.new
      @mutex = Mutex.new
      @num_threads = num_threads
      @threads = []
      start_threads
    end

    def start_threads
      @num_threads.times do
        @threads << Thread.new do
          loop do
            path, type = @file_queue.pop
            contents = read_path path
            @contents_queue << [path, type, contents]
          end
        end
      end
    end

    def read_files list, type
      @file_list[type] ||= []
      list.each do |path|
        @file_queue << [path, type]
      end

      until @file_queue.empty? and @contents_queue.empty?
        path, type, contents = @contents_queue.pop
        result = yield path, contents
        if result
          @file_list[type] << result
        end
      end
    end
  end
end
