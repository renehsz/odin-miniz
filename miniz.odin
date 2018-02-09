when ODIN_OS == "windows" {
	foreign import miniz "miniz/miniz.lib"
} else {
	foreign import miniz "miniz/libminiz.a"
}

// core:c.odin is broken :-(
when ODIN_OS == "windows" || size_of(rawptr) == 4 {
	c_long :: i32;
} else {
	c_long :: i64;
}
when ODIN_OS == "windows" || size_of(rawptr) == 4 {
	c_ulong :: u32;
} else {
	c_ulong :: u64;
}
c_size_t :: uint;
c_int    :: i32;
c_uint   :: u32;

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

	zalloc:    rawptr,    // optional heap allocation function (defaults to malloc)
	zfree:     rawptr,    // optional heap free function (defaults to free)
	opaque:    rawptr,    // heap alloc function user pointer

	data_type: c_int,     // data_type (unused)
	adler:     c_ulong,   // adler32 of the source or uncompressed data
	reserved:  c_ulong,   // not used
}

/* TODO
@(link_name="mz_version") version: ^byte;
@(link_name="miniz_def_alloc_func")   def_alloc_func   :: ^proc(opaque: rawptr, items, size: c_size_t);
@(link_name="miniz_def_free_func")    def_free_func    :: ^proc(opaque, addr: rawptr);
@(link_name="miniz_def_realloc_func") def_realloc_func :: ^proc(opaque, addr: rawptr, items, size: c_size_t);
*/

foreign miniz {
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

TinflPutBufFuncPtr :: ^proc(pBuf: rawptr, len: c_int, pUser: rawptr) -> c_int;

foreign miniz {
	@(link_name="tinfl_decompress_mem_to_heap")     tinfl_decompress_mem_to_heap     :: proc(pSrc_buf: rawptr, src_buf_len, pOut_len: c_size_t, flags: c_int) -> rawptr ---;
	@(link_name="tinfl_decompress_mem_to_mem")      tinfl_decompress_mem_to_mem      :: proc(pOut_buf: rawptr, out_buf_len: c_size_t, pSrc_buf: rawptr, src_buf_len: c_size_t, flags: c_int) -> c_size_t ---;
	@(link_name="tinfl_decompress_mem_to_callback") tinfl_decompress_mem_to_callback :: proc(pIn_buf: rawptr, pIn_buf_size: c_size_t, pPut_buf_func: TinflPutBufFuncPtr, pPut_buf_user: rawptr, flags: c_int) -> TinflStatus ---;
	@(link_name="tinfl_decompressor_alloc")         tinfl_decompressor_alloc         :: proc() -> ^TinflDecompressor ---;
	@(link_name="tinfl_decompressor_free")          tinfl_decompressor_free          :: proc(pDecomp: ^TinflDecompressor) ---;
	@(link_name="tinfl_decompress")                 tinfl_decompress                 :: proc(r: ^TinflDecompressor, pIn_buf_next: ^u8, pIn_buf_size: ^c_size_t, pOut_buf_start: ^u8, pOut_buf_next: ^u8, pOut_buf_size: ^c_size_t, decomp_flags: u32) -> TinflStatus ---;

}

// Miniz tdef


/* tdefl_init() compression flags logically OR'd together (low 12 bits contain the max. number of probes per dictionary search): */
/* DEFAULT_MAX_PROBES: The compressor defaults to 128 dictionary probes per dictionary search. 0=Huffman only, 1=Huffman+LZ (fastest/crap compression), 4095=Huffman+LZ (slowest/best compression). */
/* WRITE_ZLIB_HEADER: If set, the compressor outputs a zlib header before the deflate data, and the Adler-32 of the source data at the end. Otherwise, you'll get raw deflate data. */
/* COMPUTE_ADLER32: Always compute the adler-32 of the input data (even when not writing zlib headers). */
/* GREEDY_PARSING_FLAG: Set to use faster greedy parsing, instead of more efficient lazy parsing. */
/* NONDETERMINISTIC_PARSING_FLAG: Enable to decrease the compressor's initialization time to the minimum, but the output may vary from run to run given the same input (depending on the contents of memory). */
/* RLE_MATCHES: Only look for RLE matches (matches with a distance of 1) */
/* FILTER_MATCHES: Discards matches <= 5 chars if enabled. */
/* FORCE_ALL_STATIC_BLOCKS: Disable usage of optimized Huffman tables. */
/* FORCE_ALL_RAW_BLOCKS: Only use raw (uncompressed) deflate blocks. */
/* The low 12 bits are reserved to control the max # of hash probes per dictionary lookup (see MAX_PROBES_MASK). */
TdeflCompressionFlags :: enum {
	HUFFMAN_ONLY = 0,
	DEFAULT_MAX_PROBES = 128,
	MAX_PROBES_MASK = 0xFFF,
	WRITE_ZLIB_HEADER = 0x01000,
	COMPUTE_ADLER32 = 0x02000,
	GREEDY_PARSING_FLAG = 0x04000,
	NONDETERMINISTIC_PARSING_FLAG = 0x08000,
	RLE_MATCHES = 0x10000,
	FILTER_MATCHES = 0x20000,
	FORCE_ALL_STATIC_BLOCKS = 0x40000,
	FORCE_ALL_RAW_BLOCKS = 0x80000,
}

MAX_HUFF_TABLES                 :: 3;
MAX_HUFF_SYMBOLS_0              :: 288;
MAX_HUFF_SYMBOLS_1              :: 32;
MAX_HUFF_SYMBOLS_2              :: 19;
LZ_DICT_SIZE                    :: 32768;
LZ_DICT_SIZE_MASK               :: LZ_DICT_SIZE - 1;
MIN_MATCH_LEN                   :: 3;
MAX_MATCH_LEN                   :: 258;

/* TDEFL_OUT_BUF_SIZE MUST be large enough to hold a single entire compressed output block (using static/fixed Huffman codes). */
when false /* TDEFL_LESS_MEMORY */ {
	TDEFL_LZ_CODE_BUF_SIZE      :: 24 * 1024;
    TDEFL_OUT_BUF_SIZE          :: (TDEFL_LZ_CODE_BUF_SIZE * 13) / 10;
    TDEFL_MAX_HUFF_SYMBOLS      :: 288;
    TDEFL_LZ_HASH_BITS          :: 12;
    TDEFL_LEVEL1_HASH_SIZE_MASK :: 4095;
    TDEFL_LZ_HASH_SHIFT         :: (TDEFL_LZ_HASH_BITS + 2) / 3;
    TDEFL_LZ_HASH_SIZE          :: 1 << TDEFL_LZ_HASH_BITS;
} else {
	LZ_CODE_BUF_SIZE            :: 64 * 1024;
	OUT_BUF_SIZE                :: (LZ_CODE_BUF_SIZE * 13) / 10;
	MAX_HUFF_SYMBOLS            :: 288;
	LZ_HASH_BITS                :: 15;
	LEVEL1_HASH_SIZE_MASK       :: 4095;
	LZ_HASH_SHIFT               :: (LZ_HASH_BITS + 2) / 3;
	LZ_HASH_SIZE                :: 1 << LZ_HASH_BITS;
}

/* The low-level tdefl functions below may be used directly if the above helper functions aren't flexible enough. The low-level functions don't make any heap allocations, unlike the above helper functions. */
TdeflStatus :: enum {
	STATUS_BAD_PARAM      = -2,
	STATUS_PUT_BUF_FAILED = -1,
	STATUS_OKAY           = 0,
	STATUS_DONE           = 1,
}

/* Must map to MZ_NO_FLUSH, MZ_SYNC_FLUSH, etc. enums */
TdeflFlush :: enum {
	NO_FLUSH   = 0,
	SYNC_FLUSH = 2,
	FULL_FLUSH = 3,
	FINISH     = 4,
}

/* Output stream interface. The compressor uses this interface to write compressed data. It'll typically be called TDEFL_OUT_BUF_SIZE at a time. */
TdeflPutBufFuncPtr :: ^proc(pBuf: rawptr, len: c_int, pUser: rawptr) -> bool;

/* tdefl's compression state structure. */
TdeflCompressor :: struct {
	m_pPut_buf_func:          TdeflPutBufFuncPtr,
	m_pPut_buf_user:          rawptr,
	m_flags:                  c_uint,
	m_max_probes:             [2]c_uint,
	m_greedy_parsing:         c_int,
	m_adler32:                c_uint,
	m_lookahead_pos:          c_uint,
	m_lookahead_size:         c_uint,
	m_dict_size:              c_uint,
	m_pLZ_code_buf:           ^u8,
	m_pLZ_flags:              ^u8,
	m_pOutput_buf:            ^u8,
	m_pOutput_buf_end:        ^u8,
	m_num_flags_left:         c_uint,
	m_total_lz_bytes:         c_uint,
	m_lz_code_buf_dics_pos:   c_uint,
	m_bits_in:                c_uint,
	m_bit_buffer:             c_uint,
	m_saved_match_dist:       c_uint,
	m_saved_match_len:        c_uint,
	m_saved_lit:              c_uint,
	m_output_flush_ofs:       c_uint,
	m_output_flush_remaining: c_uint,
	m_finished:               c_uint,
	m_block_index:            c_uint,
	m_wants_to_finish:        c_uint,
	m_prev_return_status:     TdeflStatus,
	m_pIn_buf:                rawptr,
	m_pOut_buf:               rawptr,
	m_pIn_buf_size:           ^c_size_t,
	m_pOut_buf_size:          ^c_size_t,
	m_flush:                  TdeflFlush,
	m_pSrc:                   ^u8,
	m_src_buf_left,m_out_bufl:c_size_t,
	m_dict:                   [LZ_DICT_SIZE + MAX_MATCH_LEN - 1]u8,
	m_huff_count:             [MAX_HUFF_TABLES][MAX_HUFF_SYMBOLS]u16,
	m_huff_codes:             [MAX_HUFF_TABLES][MAX_HUFF_SYMBOLS]u16,
	m_huff_code_sizes:        [MAX_HUFF_TABLES][MAX_HUFF_SYMBOLS]u8,
	m_lz_code_buf:            [LZ_CODE_BUF_SIZE]u8,
	m_next:                   [LZ_DICT_SIZE]u16,
	m_hash:                   [LZ_HASH_SIZE]u16,
	m_output_buf:             [OUT_BUF_SIZE]u8,
}

foreign miniz {
	/* Initializes the compressor. */
	/* There is no corresponding deinit() function because the tdefl API's do not dynamically allocate memory. */
	/* pBut_buf_func: If NULL, output data will be supplied to the specified callback. In this case, the user should call the tdefl_compress_buffer() API for compression. */
	/* If pBut_buf_func is NULL the user should always call the tdefl_compress() API. */
	/* flags: See the above enums (TDEFL_HUFFMAN_ONLY, TDEFL_WRITE_ZLIB_HEADER, etc.) */
	@(link_name="tdefl_init")     tdefl_init     :: proc(d: ^TdeflCompressor, pPut_buf_func: TdeflPutBufFuncPtr, pPut_buf_user: rawptr, flags: c_int) -> TdeflStatus ---;

	/* Compresses a block of data, consuming as much of the specified input buffer as possible, and writing as much compressed data to the specified output buffer as possible. */
	@(link_name="tdefl_compress") tdefl_compress :: proc(d: ^TdeflCompressor, pIn_buf: rawptr, pIn_buf_size: ^c_size_t, pOut_buf: rawptr, pOut_buf_size: c_size_t, flush: TdeflFlush) -> TdeflStatus ---;

	/* tdefl_compress_buffer() is only usable when the tdefl_init() is called with a non-NULL tdefl_put_buf_func_ptr. */
	/* tdefl_compress_buffer() always consumes the entire input buffer. */
	@(link_name="tdefl_compress_buffer") tdefl_compress_buffer :: proc(d: ^TdeflCompressor, pIn_buf: rawptr, in_buf_size: c_size_t, flush: TdeflFlush) -> TdeflStatus ---;

	@(link_name="tdefl_get_prev_return_status") tdefl_get_prev_return_status :: proc(d: ^TdeflCompressor) -> TdeflStatus ---;
	@(link_name="tdefl_get_adler32")            tdefl_get_adler32            :: proc(d: ^TdeflCompressor) -> u32 ---;

	/* Create tdefl_compress() flags given zlib-style compression parameters. */
	/* level may range from [0,10] (where 10 is absolute max compression, but may be much slower on some files) */
	/* window_bits may be -15 (raw deflate) or 15 (zlib) */
	/* strategy may be either MZ_DEFAULT_STRATEGY, MZ_FILTERED, MZ_HUFFMAN_ONLY, MZ_RLE, or MZ_FIXED */
	@(link_name="tdefl_create_comp_flags_from_zip_params") tdefl_create_comp_flags_from_zip_params :: proc(level, window_bits, strategy: c_int) -> c_uint ---;
	
	/* Allocate the tdefl_compressor structure in C so that */
	/* non-C language bindings to tdefl_ API don't need to worry about */
	/* structure size and allocation mechanism. */
	@(link_name="tdefl_compressor_alloc") tdefl_compressor_alloc :: proc() -> ^TdeflCompressor ---;
	@(link_name="tdefl_compressor_free")  tdefl_compressor_free  :: proc(pComp: ^TdeflCompressor) ---;

	/* High level compression functions: */
	/* tdefl_compress_mem_to_heap() compresses a block in memory to a heap block allocated via malloc(). */
	/* On entry: */
	/*  pSrc_buf, src_buf_len: Pointer and size of source block to compress. */
	/*  flags: The max match finder probes (default is 128) logically OR'd against the above flags. Higher probes are slower but improve compression. */
	/* On return: */
	/*  Function returns a pointer to the compressed data, or NULL on failure. */
	/*  *pOut_len will be set to the compressed data's size, which could be larger than src_buf_len on uncompressible data. */
	/*  The caller must free() the returned block when it's no longer needed. */
	@(link_name="tdefl_compress_mem_to_heap")                 tdefl_compress_mem_to_heap                 :: proc(pSrc_buf: rawptr, src_buf_len, pOut_len: c_size_t, flags: c_int) -> rawptr ---;

	/* tdefl_compress_mem_to_mem() compresses a block in memory to another block in memory. */
	/* Returns 0 on failure. */
	@(link_name="tdefl_compress_mem_to_mem")                  tdefl_compress_mem_to_mem                  :: proc(pOut_buf: rawptr, out_buf_len: c_size_t, pSrc_buf: rawptr, src_buf_len: c_size_t, flags: c_int) -> c_size_t ---;

	/* Compresses an image to a compressed PNG file in memory. */
	/* On entry: */
	/*  pImage, w, h, and num_chans describe the image to compress. num_chans may be 1, 2, 3, or 4. */
	/*  The image pitch in bytes per scanline will be w*num_chans. The leftmost pixel on the top scanline is stored first in memory. */
	/*  level may range from [0,10], use MZ_NO_COMPRESSION, MZ_BEST_SPEED, MZ_BEST_COMPRESSION, etc. or a decent default is MZ_DEFAULT_LEVEL */
	/*  If flip is true, the image will be flipped on the Y axis (useful for OpenGL apps). */
	/* On return: */
	/*  Function returns a pointer to the compressed data, or NULL on failure. */
	/*  *pLen_out will be set to the size of the PNG image file. */
	/*  The caller must mz_free() the returned heap block (which will typically be larger than *pLen_out) when it's no longer needed. */
	@(link_name="tdefl_write_image_to_png_file_in_memory_ex") tdefl_write_image_to_png_file_in_memory_ex :: proc(pImage: rawptr, w, h, num_chans: c_int, pLen_out: ^c_size_t, level: c_uint, flip: bool) -> rawptr ---;
	@(link_name="tdefl_write_image_to_png_file_in_memory")    tdefl_write_image_to_png_file_in_memory    :: proc(pImage: rawptr, w, h, num_chans: c_int, pLen_out: ^c_size_t) -> rawptr ---;

	/* tdefl_compress_mem_to_output() compresses a block to an output stream. The above helpers use this function internally. */
	@(link_name="tdefl_compress_mem_to_output")               tdefl_compress_mem_to_output               :: proc(pBuf: rawptr, buf_len: c_size_t, pPut_buf_func: TdeflPutBufFuncPtr, pPut_buf_user: rawptr, flags: c_int) -> bool ---;


}

// Miniz zip
// TODO
