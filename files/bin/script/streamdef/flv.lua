function flv_file(size)
end


function flv_header()
	Signature UI8 Signature byte always 'F' (0x46)
	Signature UI8 Signature byte always 'L' (0x4C)
	Signature UI8 Signature byte always 'V' (0x56)
	Version UI8 File version (for example, 0x01 for FLV version 1)
	TypeFlagsReserved UB [5] Shall be 0
	TypeFlagsAudio UB [1] 1 = Audio tags are present
	TypeFlagsReserved UB [1] Shall be 0
	TypeFlagsVideo UB [1] 1 = Video tags are present
	DataOffset UI32 The length of this header in bytes
end

function flv_file_body()
	PreviousTagSize0 UI32 Always 0
	Tag1 FLVTAG First tag
	PreviousTagSize1 UI32 Size of previous tag, including its header, in bytes. For FLV version
	1, this value is 11 plus the DataSize of the previous tag.
	Tag2 FLVTAG Second tag
	...
	PreviousTagSizeN-1 UI32 Size of second-to-last tag, including its header, in bytes.
	TagN FLVTAG Last tag
	PreviousTagSizeN UI32 Size of last tag, including its header, in bytes.
end

function flv_tag()
	Reserved UB [2] Reserved for FMS, should be 0
	Filter UB [1] Indicates if packets are filtered.
	0 = No pre-processing required.
	1 = Pre-processing (such as decryption) of the packet is
	required before it can be rendered.
	Shall be 0 in unencrypted files, and 1 for encrypted tags.
	See Annex F. FLV Encryption for the use of filters.
	TagType UB [5] Type of contents in this tag. The following types are
	defined:
	8 = audio
	9 = video
	18 = script data
	DataSize UI24 Length of the message. Number of bytes after StreamID to
	end of tag (Equal to length of the tag ? 11)
	Timestamp UI24 Time in milliseconds at which the data in this tag applies.
	This value is relative to the first tag in the FLV file, which
	always has a timestamp of 0.
	TimestampExtended UI8 Extension of the Timestamp field to form a SI32 value. This
	field represents the upper 8 bits, while the previous
	Timestamp field represents the lower 24 bits of the time in
	milliseconds.
	StreamID UI24 Always 0.
	AudioTagHeader IF TagType == 8
	AudioTagHeader
	AudioTagHeader element as defined in Section E.4.2.1.
	VideoTagHeader IF TagType == 9
	VideoTagHeader
	VideoTagHeader element as defined in Section E.4.3.1.
	EncryptionHeader IF Filter == 1
	EncryptionTagHeader
	Encryption header shall be included for each protected
	sample, as defined in Section F.3.1.
	FilterParams IF Filter == 1
	FilterParams
	FilterParams shall be included for each protected sample, as
	defined in Section F.3.2.
	Data IF TagType == 8
	AUDIODATA
	IF TagType == 9
	VIDEODATA
	IF TagType == 18
	SCRIPTDATA
	Data specific for each media type.
	In
end

function audio_tag_header()
	
end

enable_print(false)
flv_file(get_size())

