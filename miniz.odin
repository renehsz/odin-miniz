when ODIN_OS == "windows" {
	foreign import miniz "miniz/miniz.lib"
} else {
	foreign import miniz "miniz/libminiz.a"
}

// core:c.odin is broken :-(
when ODIN_OS == "windows" || size_of(rawptr) == 4 {
	c_long :: #alias i32;
} else {
	c_long :: #alias i64;
}
when ODIN_OS == "windows" || size_of(rawptr) == 4 {
	c_ulong :: #alias u32;
} else {
	c_ulong :: #alias u64;
}
c_size_t :: uint;
c_int :: i32;

// Miniz common
CompressionLevel :: enum {
	NO_COMPRESSION      = 0,
	BEST_SPEED          = 1,
	BEST_COMPRESSION    = 9,
	UBER_COMPRESSION    = 10,
	DEFAULT_LEVEL       = 6,
	DEFAULT_COMPRESSION = -1,
}

FlushValue :: enum {
	NO_FLUSH      = 0,
	PARTIAL_FLUSH = 1,
	SYNC_FLUSH    = 2,
	FULL_FLUSH    = 3,
	FINISH        = 4,
	BLOCK         = 5,
}

ReturnStatusCode :: enum {
	OK            =  0,
	STREAM_END    =  1,
	NEED_DICT     =  2,
	ERRNO         = -1,
	STREAM_ERROR  = -2,
	DATA_ERROR    = -3,
	MEM_ERROR     = -4,
	BUF_ERROR     = -5,
	VERSION_ERROR = -6,
	PARAM_ERROR   = -10000,
}

Stream :: struct {
	next_in:   ^byte,     // pointer to next byte to read
	avail_in:  c_uint,    // number of bytes available at next_in
	total_in:  c_ulong,   // total number of bytes consumed so far

	next_out:  ^byte,     // pointer to next byte to write
	avail_out: c_uint,    // number of bytes that can be written to next_out
	total_out: c_ulong,   // total number of bytes produced so far

	msg:       ^byte,     // error msg (unused)
	state:     rawptr,    // internal state, allocated by zalloc/zfree

	zalloc:    AllocFunc, // optional heap allocation function (defaults to malloc)
	zfree:     FreeFunc,  // optional heap free function (defaults to free)
	opaque:    rawptr,    // heap alloc function user pointer

	data_type: c_int,     // data_type (unused)
	adler:     c_ulong,   // adler32 of the source or uncompressed data
	reserved:  c_ulong,   // not used
}

foreign miniz {
	@(link_name="mz_version") version: ^byte;
	@(link_name="miniz_def_alloc_func")   def_alloc_func   :: ^proc(opaque: rawptr, items, size: c_size_t);
	@(link_name="miniz_def_free_func")    def_free_func    :: ^proc(opaque, addr: rawptr);
	@(link_name="miniz_def_realloc_func") def_realloc_func :: ^proc(opaque, addr: rawptr, items, size: c_size_t);

	@(link_name="mz_free")          free    :: proc(p: rawptr) ---;

	@(link_name="mz_adler32")       adler32 :: proc(adler: c_ulong, ptr: ^byte, buf_len: c_size_t) -> c_ulong ---;
	@(link_name="mz_crc32")         crc32   :: proc(crc: c_ulong, ptr: ^byte, buf_len: c_size_t) -> c_ulong ---;

	@(link_name="mz_deflateInit")   deflate_init :: proc(pStream: ^Stream, level: c_int) -> ReturnStatusCode ---;
	@(link_name="mz_deflateInit2")  deflate_init_2 :: proc(pStream: ^Stream, level, method, window_bits, mem_level, strategy: c_int) -> ReturnStatusCode ---;
	@(link_name="mz_deflateReset")  deflate_reset  :: proc(pStream: ^Stream) -> ReturnStatusCode ---;
	@(link_name="mz_deflate")       deflate        :: proc(pStream: ^Stream, flush: c_int) -> ReturnStatusCode ---;
	@(link_name="mz_deflateEnd")    deflate_end    :: proc(pStream: ^Stream) -> ReturnStatusCode ---;
	@(link_name="mz_deflateBound")  deflate_bound  :: proc(pStream: ^Stream, source_len: c_ulong) -> c_ulong ---;

	@(link_name="mz_compress")      compress       :: proc(pDest: ^byte, pDest_len: ^c_ulong, pSource: ^byte, source_len: c_ulong) -> ReturnStatusCode ---;
	@(link_name="mz_compress2")     compress_2     :: proc(pDest: ^byte, pDest_len: ^c_ulong, pSource: ^byte, source_len: c_ulong) -> ReturnStatusCode ---;
	@(link_name="mz_compressBound") compress_bound :: proc(source_len: c_ulong) -> c_ulong ---;

	@(link_name="mz_inflateInit")   inflate_init   :: proc(pStream: ^Stream) -> ReturnStatusCode ---;
	@(link_name="mz_inflateInit2")  inflate_init_2 :: proc(pStream: ^Stream, window_bits: c_int) -> ReturnStatusCode ---;
	@(link_name="mz_inflate")       inflate        :: proc(pStream: ^Stream, flush: c_int) -> ReturnStatusCode ---;
	@(link_name="mz_inflateEnd")    inflate_end    :: proc(pStream: ^Stream) -> ReturnStatusCode ---;

	@(link_name="mz_uncompress")    uncompress     :: proc(pDest: ^byte, pDest_len: c_ulong, pSource: ^byte, source_len: c_ulong) -> ReturnStatusCode ---;

	@(link_name="mz_error")         error          :: proc(err: c_int) -> ^byte ---;
}

// Miniz tinfl
// TODO(ReneHSZ): Macros TINFL_HUFF_BITBUF_FILL, TINFL_HUFF_DECODE, ...
TinflFlag :: enum {
	PARSE_ZLIB_HEADER             = 1,
	HAS_MORE_INPUT                = 2,
	USING_NON_WRAPPING_OUTPUT_BUF = 4,
	COMPUTE_ADLER32               = 8,
}

TinflStatus :: enum {
	/* This flags indicates the inflator needs 1 or more input bytes to make forward progress, but the caller is indicating that no more are available. The compressed data */
    /* is probably corrupted. If you call the inflator again with more bytes it'll try to continue processing the input but this is a BAD sign (either the data is corrupted or you called it incorrectly). */
    /* If you call it again with no input you'll just get TINFL_STATUS_FAILED_CANNOT_MAKE_PROGRESS again. */
    TINFL_STATUS_FAILED_CANNOT_MAKE_PROGRESS = -4,

    /* This flag indicates that one or more of the input parameters was obviously bogus. (You can try calling it again, but if you get this error the calling code is wrong.) */
    TINFL_STATUS_BAD_PARAM        = -3,

    /* This flags indicate the inflator is finished but the adler32 check of the uncompressed data didn't match. If you call it again it'll return TINFL_STATUS_DONE. */
    TINFL_STATUS_ADLER32_MISMATCH = -2,

    /* This flags indicate the inflator has somehow failed (bad code, corrupted input, etc.). If you call it again without resetting via tinfl_init() it it'll just keep on returning the same status failure code. */
    TINFL_STATUS_FAILED           = -1,

    /* Any status code less than TINFL_STATUS_DONE must indicate a failure. */

    /* This flag indicates the inflator has returned every byte of uncompressed data that it can, has consumed every byte that it needed, has successfully reached the end of the deflate stream, and */
    /* if zlib headers and adler32 checking enabled that it has successfully checked the uncompressed data's adler32. If you call it again you'll just get TINFL_STATUS_DONE over and over again. */
    TINFL_STATUS_DONE             = 0,

    /* This flag indicates the inflator MUST have more input data (even 1 byte) before it can make any more forward progress, or you need to clear the TINFL_FLAG_HAS_MORE_INPUT */
    /* flag on the next call if you don't have any more source data. If the source data was somehow corrupted it's also possible (but unlikely) for the inflator to keep on demanding input to */
    /* proceed, so be sure to properly set the TINFL_FLAG_HAS_MORE_INPUT flag. */
    TINFL_STATUS_NEEDS_MORE_INPUT = 1,

    /* This flag indicates the inflator definitely has 1 or more bytes of uncompressed data available, but it cannot write this data into the output buffer. */
    /* Note if the source compressed data was corrupted it's possible for the inflator to return a lot of uncompressed data to the caller. I've been assuming you know how much uncompressed data to expect */
    /* (either exact or worst case) and will stop calling the inflator and fail after receiving too much. In pure streaming scenarios where you have no idea how many bytes to expect this may not be possible */
    /* so I may need to add some code to address this. */
    TINFL_STATUS_HAS_MORE_OUTPUT  = 2,
}

TinflDecompressor :: struct {
	// Note(ReneHSZ): This can be left empty, because we are only dealing with pointers to this structure and it is allocated in C.
}

foreign miniz {
	@(link_name="tinfl_decompress_mem_to_heap")     tinfl_decompress_mem_to_heap     :: proc(pSrc_buf: rawptr, src_buf_len, pOut_len: c_size_t, flags: c_int) -> rawptr ---;
	@(link_name="tinfl_decompress_mem_to_mem")      tinfl_decompress_mem_to_mem      :: proc(pOut_buf: rawptr, out_buf_len: c_size_t, pSrc_buf: rawptr, src_buf_len: c_size_t, flags: c_int) -> c_size_t ---;
	@(link_name="tinfl_decompress_mem_to_callback") tinfl_decompress_mem_to_callback :: proc(pIn_buf: rawptr, pIn_buf_size: c_size_t, pPut_buf_func: TinflPutBufFuncPtr, pPut_buf_user: rawptr, flags: c_int) -> TinflStatus ---;
	@(link_name="tinfo_decompressor_alloc")         tinfl_decompressor_alloc         :: proc() -> ^TinflDecompressor ---;
	@(link_name="tinfl_decompressor_free")          tinfl_decompressor_free          :: proc(pDecomp: ^TinflDecompressor) ---;
	@(link_name="tinfl_decompress")                 tinfl_decompress                 :: proc(r: ^TinfoDecompressor, pIn_buf_next: ^u8, pIn_buf_size: ^c_size_t, pOut_buf_start: ^u8, pOut_buf_next: ^u8, pOut_buf_size: ^c_size_t, decomp_flags: u32) -> TinflStatus ---;

}

// Miniz tdef
// TODO

// Miniz zip
// TODO
