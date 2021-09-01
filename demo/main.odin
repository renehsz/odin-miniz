package main

import "core:log"
import "core:os"
import miniz ".."

when ODIN_DEBUG {
    BUFFER_SIZE :: 8;
} else {
    BUFFER_SIZE :: 4*1024*1024;
}

in_buf, out_buf: [BUFFER_SIZE]byte;

main :: proc() {
    context.logger = log.create_console_logger();

    in_filename := "test.txt";
    out_filename := "test.deflate";
    in_file, out_file: os.Handle;
    err: os.Errno;

    // Open input and output files.
    in_file, err = os.open(in_filename, os.O_RDONLY);
    if err != os.ERROR_NONE {
        log.fatalf("Failed to open input file \"%s\" for reading.", in_filename);
        os.exit(1);
    }
    defer os.close(in_file);

    out_file, err = os.open(out_filename, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, 0o644);
    if err != os.ERROR_NONE {
        log.fatalf("Failed to open output file \"%s\" for writing.", out_filename);
        os.exit(1);
    }
    defer os.close(out_file);

    // Setup deflate compressor.
    level := miniz.Compression_Level.BEST_COMPRESSION;
    stream: miniz.Stream = {
        next_in   = raw_data(in_buf[:]),
        avail_in  = 0,
        next_out  = raw_data(out_buf[:]),
        avail_out = BUFFER_SIZE,
    };
    if miniz.deflate_init(&stream, level) != miniz.Return_Status_Code.OK {
        log.fatalf("Failed to initialize deflate compression for \"%s\".", in_filename);
        os.exit(1);
    }

    reached_eof := false;
    for {
        if stream.avail_in <= 0 {
            // Input buffer is empty, try to read more bytes from the file.
            num_read, err := os.read(in_file, in_buf[:]);
            if err != os.ERROR_NONE {
                log.fatalf("Failed to read from input file \"%s\".", in_filename);
            }
            if num_read == 0 {
                reached_eof = true;
            }
            log.debugf("read %d bytes from input file", num_read);

            stream.next_in = raw_data(in_buf[:]);
            stream.avail_in = cast(u32) num_read;
        }

        // Do the compression.
        status := miniz.deflate(&stream, reached_eof ? miniz.Flush_Value.FINISH : miniz.Flush_Value.NO_FLUSH);

        if status == miniz.Return_Status_Code.STREAM_END || stream.avail_out <= 0 {
            // Output buffer is full or compression is done.
            n := int(BUFFER_SIZE) - int(stream.avail_out);

            num_written, err := os.write(out_file, out_buf[:n]);
            if err != os.ERROR_NONE || num_written != n {
                log.fatalf("Failed to write to output file \"%s\".", out_filename);
            }
            log.debugf("wrote %d bytes to output file", num_written);

            stream.next_out = raw_data(out_buf[:]);
            stream.avail_out = BUFFER_SIZE;
        }

        if status == miniz.Return_Status_Code.STREAM_END {
            log.debugf("end of input file reached");
            break;
        }
    }

    if (miniz.deflate_end(&stream) != miniz.Return_Status_Code.OK) {
        log.fatalf("Failed to end deflate compression for \"%s\".", in_filename);
        os.exit(1);
    }

    log.infof("Successfully compressed file \"%s\" to \"%s\".", in_filename, out_filename);
}

