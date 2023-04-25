#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'

module Artichoke
  module Playground
    module Build
      RUSTFLAGS = %w[
        -C link-arg=-sMODULARIZE=1
        -C link-arg=-sWASM=1
        -C link-arg=-sWASMFS=1
        -C link-arg=-sENVIRONMENT=web
        -C link-arg=-sSUPPORT_LONGJMP=1
      ].freeze

      USAGE = <<~USAGE.freeze
        build-wasm.rb - Artichoke Ruby Playground WebAssembly Builder
        Ryan Lopopolo <rjl@hyperbo.la>

        USAGE: #{$PROGRAM_NAME} [OPTIONS] [ --release ]

        OPTIONS:
            -v, --verbose
                    Emit verbose output when compiling with cargo.

      USAGE

      def self.debug(verbose: false)
        ENV['RUSTFLAGS'] = RUSTFLAGS.join(' ')
        # Rust compilation on `wasm32-unknown-emscripten` fails during linking
        # due to a dependency on missing symbol `__gxx_personality_v0`. This has
        # been broken since Rust 1.53.0 and emsdk newer than 2.0.9.
        #
        # These flags work around the problem by letting the emcc linker ignore
        # the missing symbol error.
        #
        # - https://github.com/zackradisic/cheatsheets/issues/21#issuecomment-969393554
        # - https://github.com/rust-lang/rust/issues/85821#issuecomment-969369677
        ENV['EMCC_CFLAGS'] = '-s ERROR_ON_UNDEFINED_SYMBOLS=0 --no-entry'

        if verbose
          `cargo build --target wasm32-unknown-emscripten --verbose`
        else
          `cargo build --target wasm32-unknown-emscripten`
        end

        begin
          return if [
            FileUtils.compare_file(
              'target/wasm32-unknown-emscripten/debug/playground.js',
              'src/wasm/playground.js'
            ),
            FileUtils.compare_file(
              'target/wasm32-unknown-emscripten/debug/playground.wasm',
              'src/wasm/playground.wasm'
            ),
            FileUtils.compare_file(
              'target/wasm32-unknown-emscripten/debug/playground.wasm.map',
              'src/wasm/playground.wasm.map'
            )
          ].all?
        rescue ArgumentError, Errno::ENOENT
          # pass - if destination files don't exist, `compare_file` will raise
          # `ENOENT`, which means the files are not equal and we should proceed
          # with the copy.
        end

        FileUtils.cp(
          ['target/wasm32-unknown-emscripten/debug/playground.js',
           'target/wasm32-unknown-emscripten/debug/playground.wasm',
           'target/wasm32-unknown-emscripten/debug/playground.wasm.map'],
          'src/wasm/'
        )
      rescue ArgumentError, Errno::ENOENT
        # pass
      end

      def self.release(verbose: false)
        ENV['RUSTFLAGS'] = RUSTFLAGS.join(' ')
        # Rust compilation on `wasm32-unknown-emscripten` fails during linking
        # due to a dependency on missing symbol `__gxx_personality_v0`. This has
        # been broken since Rust 1.53.0 and emsdk newer than 2.0.9.
        #
        # These flags work around the problem by letting the emcc linker ignore
        # the missing symbol error.
        #
        # - https://github.com/zackradisic/cheatsheets/issues/21#issuecomment-969393554
        # - https://github.com/rust-lang/rust/issues/85821#issuecomment-969369677
        ENV['EMCC_CFLAGS'] = '-s ERROR_ON_UNDEFINED_SYMBOLS=0 --no-entry'

        if verbose
          `cargo build --target wasm32-unknown-emscripten --release --verbose`
        else
          `cargo build --target wasm32-unknown-emscripten --release`
        end

        begin
          return if [
            FileUtils.compare_file(
              'target/wasm32-unknown-emscripten/release/playground.js',
              'src/wasm/playground.js'
            ),
            FileUtils.compare_file(
              'target/wasm32-unknown-emscripten/release/playground.wasm',
              'src/wasm/playground.wasm'
            ),
            FileUtils.compare_file(
              'target/wasm32-unknown-emscripten/release/playground.wasm.map',
              'src/wasm/playground.wasm.map'
            )
          ].all?
        rescue ArgumentError, Errno::ENOENT
          # pass - if destination files don't exist, `compare_file` will raise
          # `ENOENT`, which means the files are not equal and we should proceed
          # with the copy.
        end

        FileUtils.cp(
          ['target/wasm32-unknown-emscripten/release/playground.js',
           'target/wasm32-unknown-emscripten/release/playground.wasm',
           'target/wasm32-unknown-emscripten/release/playground.wasm.map'],
          'src/wasm/'
        )
      rescue ArgumentError, Errno::ENOENT
        # pass
      end

      def self.main
        args = ARGV.each_with_object({}) do |arg, memo|
          memo[arg] = arg
        end

        verbose = false
        help = false
        args.delete_if do |key, _|
          if ['-v', '--verbose'].include?(key)
            verbose = true
            next true
          end
          if ['-h', '--help'].include?(key)
            help = true
            next true
          end
          false
        end

        if help
          puts USAGE
          Process.exit(0)
        end

        argv = args.keys.freeze
        if argv == ['--release']
          release(verbose:)
        elsif argv.empty?
          debug(verbose:)
        else
          warn USAGE
          Process.exit(2)
        end
      end
    end
  end
end

Artichoke::Playground::Build.main if __FILE__ == $PROGRAM_NAME
