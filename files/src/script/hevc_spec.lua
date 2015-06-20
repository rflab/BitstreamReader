
	                                              
function slice_segment_data( ) 
	                                              do 
	coding_tree_unit( )
	rexp("end_of_slice_segment_flag"                                              ) -- ae(v))
	CtbAddrInTs++                                              	CtbAddrInRs  CtbAddrTsToRs[CtbAddrInTs]
	if ( !end_of_slice_segment_flag and ( ( tiles_enabled_flag and TileId[CtbAddrInTs] != TileId[CtbAddrInTs ? 1] ) or ( entropy_coding_sync_enabled_flag and ( CtbAddrInTs % PicWidthInCtbsY = = 0 or TileId[CtbAddrInTs] != TileId[CtbAddrRsToTs[CtbAddrInRs ? 1]] ) ) ) ) == true then 
	end_of_subset_one_bit -- equal to 1                                               ae(v)
	byte_alignment( )
	end
	end while( !end_of_slice_segment_flag )
	end

function coding_tree_unit( ) 
	                                              	xCtb  ( CtbAddrInRs % PicWidthInCtbsY ) << CtbLog2SizeY
	yCtb  ( CtbAddrInRs / PicWidthInCtbsY ) << CtbLog2SizeY
	if ( slice_sao_luma_flag or slice_sao_chroma_flag ) == true then
	sao( xCtb >> CtbLog2SizeY, yCtb >> CtbLog2SizeY )
	coding_quadtree( xCtb, yCtb, CtbLog2SizeY, 0 )
	end
	
	
function sao( rx, ry )
	                                              	if ( rx > 0 ) == true then 
	leftCtbInSliceSeg  CtbAddrInRs > SliceAddrRs
	leftCtbInTile = TileId[CtbAddrInTs] =  TileId[CtbAddrRsToTs[CtbAddrInRs ? 1]]
	if ( leftCtbInSliceSeg and leftCtbInTile ) == true then
	rexp("sao_merge_left_flag"                                              ) -- ae(v))
	end
	if ( ry > 0 and !sao_merge_left_flag ) == true then 
	upCtbInSliceSeg = ( CtbAddrInRs ? PicWidthInCtbsY ) > SliceAddrRs
	upCtbInTile = TileId[CtbAddrInTs] =  TileId[CtbAddrRsToTs[CtbAddrInRs ? PicWidthInCtbsY]]
	if ( upCtbInSliceSeg and upCtbInTile ) == true then
	rexp("sao_merge_up_flag"                                              ) -- ae(v))
	end
	if ( !sao_merge_up_flag and !sao_merge_left_flag ) == true then
	for  cIdx = 0; cIdx < ( ChromaArrayType != 0 ? 3 : 1 ); cIdx++  do
	if ( ( slice_sao_luma_flag and cIdx = = 0 ) or ( slice_sao_chroma_flag and cIdx > 0 ) ) == true then 
	if ( cIdx = = 0 ) == true then
	rexp("sao_type_idx_luma"                                              ) -- ae(v))
	elseif ( cIdx = = 1 ) == true then
	rexp("sao_type_idx_chroma"                                              ) -- ae(v))
	if ( SaoTypeIdx[cIdx][rx][ry] != 0 ) == true then 
	for  i = 0; i < 4; i++  do
	rexp("sao_offset_abs[cIdx][rx][ry][i]"                                              ) -- ae(v))
	if ( SaoTypeIdx[cIdx][rx][ry] = = 1 ) == true then 
	for  i = 0; i < 4; i++  do
	if ( sao_offset_abs[cIdx][rx][ry][i] != 0 ) == true then
	rexp("sao_offset_sign[cIdx][rx][ry][i]"                                              ) -- ae(v))
	rexp("sao_band_position[cIdx][rx][ry]"                                              ) -- ae(v))
	elseif 
	if ( cIdx = = 0 ) == true then
	rexp("sao_eo_class_luma"                                              ) -- ae(v))
	if ( cIdx = = 1 ) == true then
	rexp("sao_eo_class_chroma"                                              ) -- ae(v))
	end
	end
	end
	end
	   
function coding_quadtree( x0, y0, log2CbSize, cqtDepth ) 
	                                              	if ( x0 + ( 1 << log2CbSize ) <= pic_width_in_luma_samples and y0 + ( 1 << log2CbSize ) <= pic_height_in_luma_samples and log2CbSize > MinCbLog2SizeY ) == true then
	rexp("split_cu_flag[x0][y0]"                                              ) -- ae(v))
	if ( cu_qp_delta_enabled_flag and log2CbSize >= Log2MinCuQpDeltaSize ) == true then 
	IsCuQpDeltaCoded  0
	CuQpDeltaVal  0
	end
	if ( cu_chroma_qp_offset_enabled_flag and log2CbSize >= Log2MinCuChromaQpOffsetSize ) == true then
	IsCuChromaQpOffsetCoded  0
	if ( split_cu_flag[x0][y0] ) == true then 
	x1  x0 + ( 1 << ( log2CbSize ? 1 ) )
	y1  y0 + ( 1 << ( log2CbSize ? 1 ) )
	coding_quadtree( x0, y0, log2CbSize ? 1, cqtDepth + 1 )
	if ( x1 < pic_width_in_luma_samples ) == true then
	coding_quadtree( x1, y0, log2CbSize ? 1, cqtDepth + 1 )
	if ( y1 < pic_height_in_luma_samples ) == true then
	coding_quadtree( x0, y1, log2CbSize ? 1, cqtDepth + 1 )
	if ( x1 < pic_width_in_luma_samples and y1 < pic_height_in_luma_samples ) == true then
	coding_quadtree( x1, y1, log2CbSize ? 1, cqtDepth + 1 )
	elseif
	coding_unit( x0, y0, log2CbSize )
	end

function coding_unit( x0, y0, log2CbSize ) 
	                                              	if ( transquant_bypass_enabled_flag ) == true then
	rexp("cu_transquant_bypass_flag"                                              ) -- ae(v))
	if ( slice_type != I ) == true then
	rexp("cu_skip_flag[x0][y0]"                                              ) -- ae(v))
	nCbS  ( 1 << log2CbSize )
	if ( cu_skip_flag[x0][y0] ) == true then
	prediction_unit( x0, y0, nCbS, nCbS )
	else 
	if ( slice_type != I ) == true then
	rexp("pred_mode_flag"                                              ) -- ae(v))
	if ( CuPredMode[x0][y0] != MODE_INTRA or log2CbSize = = MinCbLog2SizeY ) == true then
	rexp("part_mode"                                              ) -- ae(v))
	if ( CuPredMode[x0][y0] = = MODE_INTRA ) == true then 
	if ( PartMode = = PART_2Nx2N and pcm_enabled_flag and log2CbSize >= Log2MinIpcmCbSizeY and log2CbSize <= Log2MaxIpcmCbSizeY ) == true then
	rexp("pcm_flag[x0][y0]"                                              ) -- ae(v))
	if ( pcm_flag[x0][y0] ) == true then 
	while( !byte_aligned( ) )
	pcm_alignment_zero_bit                                              f(1)
	pcm_sample( x0, y0, log2CbSize )
	elseif 
	pbOffset = ( PartMode =  PART_NxN ) ? ( nCbS / 2 ) : nCbS
	for  j = 0; j < nCbS; j = j + pbOffset  do
	for  i = 0; i < nCbS; i = i + pbOffset  do
	prev_intra_luma_pred_flag[x0 + i][y0 + j]                                              ae(v)
	for  j = 0; j < nCbS; j = j + pbOffset  do
	for  i = 0; i < nCbS; i = i + pbOffset  do
	if ( prev_intra_luma_pred_flag[x0 + i][y0 + j] ) == true then
	mpm_idx[x0 + i][y0 + j]                                              ae(v)
	else
	rem_intra_luma_pred_mode[x0 + i][y0 + j]                                              ae(v)
	if ( ChromaArrayType = = 3 ) == true then
	for  j = 0; j < nCbS; j = j + pbOffset  do
	for  i = 0; i < nCbS; i = i + pbOffset  do
	intra_chroma_pred_mode[x0 + i][y0 + j]                                              ae(v)
	elseif ( ChromaArrayType != 0 ) == true then
	rexp("intra_chroma_pred_mode[x0][y0]"                                              ) -- ae(v))
	end
	elseif 
	if ( PartMode = = PART_2Nx2N ) == true then
	prediction_unit( x0, y0, nCbS, nCbS )
	elseif ( PartMode = = PART_2NxN ) == true then 
	prediction_unit( x0, y0, nCbS, nCbS / 2 )
	prediction_unit( x0, y0 + ( nCbS / 2 ), nCbS, nCbS / 2 )
	elseif ( PartMode = = PART_Nx2N ) == true then 
	prediction_unit( x0, y0, nCbS / 2, nCbS )
	prediction_unit( x0 + ( nCbS / 2 ), y0, nCbS / 2, nCbS )
	elseif ( PartMode = = PART_2NxnU ) == true then 
	prediction_unit( x0, y0, nCbS, nCbS / 4 )
	prediction_unit( x0, y0 + ( nCbS / 4 ), nCbS, nCbS * 3 / 4 )
	elseif ( PartMode = = PART_2NxnD ) == true then 
	prediction_unit( x0, y0, nCbS, nCbS * 3 / 4 )
	prediction_unit( x0, y0 + ( nCbS * 3 / 4 ), nCbS, nCbS / 4 )
	elseif ( PartMode = = PART_nLx2N ) == true then 
	prediction_unit( x0, y0, nCbS / 4, nCbS )
	prediction_unit( x0 + ( nCbS / 4 ), y0, nCbS * 3 / 4, nCbS )
	elseif ( PartMode = = PART_nRx2N ) == true then 
	prediction_unit( x0, y0, nCbS * 3 / 4, nCbS )
	prediction_unit( x0 + ( nCbS * 3 / 4 ), y0, nCbS / 4, nCbS )
	elseif  -- PART_NxN 
	prediction_unit( x0, y0, nCbS / 2, nCbS / 2 )
	prediction_unit( x0 + ( nCbS / 2 ), y0, nCbS / 2, nCbS / 2 )
	prediction_unit( x0, y0 + ( nCbS / 2 ), nCbS / 2, nCbS / 2 )
	prediction_unit( x0 + ( nCbS / 2 ), y0 + ( nCbS / 2 ), nCbS / 2, nCbS / 2 )
	end
	end
	if ( !pcm_flag[x0][y0] ) == true then 
	if ( CuPredMode[x0][y0] != MODE_INTRA and !( PartMode = = PART_2Nx2N and merge_flag[x0][y0] ) ) == true then
	rexp("rqt_root_cbf"                                              ) -- ae(v))
	if ( rqt_root_cbf ) == true then 
	MaxTrafoDepth = ( CuPredMode[x0][y0] =  MODE_INTRA ? ( max_transform_hierarchy_depth_intra + IntraSplitFlag ) : max_transform_hierarchy_depth_inter )
transform_tree( x0, y0, x0, y0, log2CbSize, 0, 0 )
	end
	end
	end
	end

function  prediction_unit( x0, y0, nPbW, nPbH ) 
	                                              	if ( cu_skip_flag[x0][y0] ) == true then 
	if ( MaxNumMergeCand > 1 ) == true then
	rexp("merge_idx[x0][y0]"                                              ) -- ae(v))
	elseif  -- MODE_INTER 
	rexp("merge_flag[x0][y0]"                                              ) -- ae(v))
	if ( merge_flag[x0][y0] ) == true then 
	if ( MaxNumMergeCand > 1 ) == true then
	rexp("merge_idx[x0][y0]"                                              ) -- ae(v))
	elseif 
	if ( slice_type = = B ) == true then
	rexp("inter_pred_idc[x0][y0]"                                              ) -- ae(v))
	if ( inter_pred_idc[x0][y0] != PRED_L1 ) == true then 
	if ( num_ref_idx_l0_active_minus1 > 0 ) == true then
	rexp("ref_idx_l0[x0][y0]"                                              ) -- ae(v))
	mvd_coding( x0, y0, 0 )
	rexp("mvp_l0_flag[x0][y0]"                                              ) -- ae(v))
	end
	if ( inter_pred_idc[x0][y0] != PRED_L0 ) == true then 
	if ( num_ref_idx_l1_active_minus1 > 0 ) == true then
	rexp("ref_idx_l1[x0][y0]"                                              ) -- ae(v))
	if ( mvd_l1_zero_flag and inter_pred_idc[x0][y0] = = PRED_BI ) == true then 
	MvdL1[x0][y0][0]  0
	MvdL1[x0][y0][1]  0
	elseif
	mvd_coding( x0, y0, 1 )
	rexp("mvp_l1_flag[x0][y0]"                                              ) -- ae(v))
	end
	end
	end
	end

function  pcm_sample( x0, y0, log2CbSize ) 
	                                              	for  i = 0; i < 1 << ( log2CbSize << 1 ); i++  do
	rbit("pcm_sample_luma[i]",                                              v) -- u(v))
	if ( ChromaArrayType != 0 ) == true then
	for  i = 0; i < ( ( 2 << ( log2CbSize << 1 ) ) / ( SubWidthC * SubHeightC ) ); i++  do
	rbit("pcm_sample_chroma[i]",                                              v) -- u(v))
	end

function  transform_tree( x0, y0, xBase, yBase, log2TrafoSize, trafoDepth, blkIdx ) 
	                                              	if ( log2TrafoSize <= MaxTbLog2SizeY and log2TrafoSize > MinTbLog2SizeY and trafoDepth < MaxTrafoDepth and !( IntraSplitFlag and ( trafoDepth = = 0 ) ) ) == true then
	rexp("split_transform_flag[x0][y0][trafoDepth]"                                              ) -- ae(v))
	if ( ( log2TrafoSize > 2 and ChromaArrayType != 0 ) or ChromaArrayType = = 3 ) == true then 
	if ( trafoDepth = = 0 or cbf_cb[xBase][yBase][trafoDepth ? 1] ) == true then 
	rexp("cbf_cb[x0][y0][trafoDepth]"                                              ) -- ae(v))
	if ( ChromaArrayType = = 2 and ( !split_transform_flag[x0][y0][trafoDepth] or log2TrafoSize = = 3 ) ) == true then
cbf_cb[x0][y0 + ( 1 << ( log2TrafoSize ? 1 ) )][trafoDepth]
	ae(v)
	end
	if ( trafoDepth = = 0 or cbf_cr[xBase][yBase][trafoDepth ? 1] ) == true then 
	rexp("cbf_cr[x0][y0][trafoDepth]"                                              ) -- ae(v))
	if ( ChromaArrayType = = 2 and ( !split_transform_flag[x0][y0][trafoDepth] or log2TrafoSize = = 3 ) ) == true then
cbf_cr[x0][y0 + ( 1 << ( log2TrafoSize ? 1 ) )][trafoDepth]
	ae(v)
	end
	end
	if ( split_transform_flag[x0][y0][trafoDepth] ) == true then 
	x1  x0 + ( 1 << ( log2TrafoSize ? 1 ) )
	y1  y0 + ( 1 << ( log2TrafoSize ? 1 ) )
transform_tree( x0, y0, x0, y0, log2TrafoSize ? 1, trafoDepth + 1, 0 )
transform_tree( x1, y0, x0, y0, log2TrafoSize ? 1, trafoDepth + 1, 1 )
transform_tree( x0, y1, x0, y0, log2TrafoSize ? 1, trafoDepth + 1, 2 )
transform_tree( x1, y1, x0, y0, log2TrafoSize ? 1, trafoDepth + 1, 3 )
	elseif 
	if ( CuPredMode[x0][y0] = = MODE_INTRA or trafoDepth != 0 or cbf_cb[x0][y0][trafoDepth] or cbf_cr[x0][y0][trafoDepth] or ( ChromaArrayType = = 2 and ( cbf_cb[x0][y0 + ( 1 << ( log2TrafoSize ? 1 ) )][trafoDepth] or cbf_cr[x0][y0 + ( 1 << ( log2TrafoSize ? 1 ) )][trafoDepth] ) ) ) == true then
	rexp("cbf_luma[x0][y0][trafoDepth]"                                              ) -- ae(v))
transform_unit( x0, y0, xBase, yBase, log2TrafoSize, trafoDepth, blkIdx )
	end
	end
	
function mvd_coding( x0, y0, refList ) 
	                                              abs_mvd_greater0_flag[0]
	ae(v)
	rexp("abs_mvd_greater0_flag[1]"                                              ) -- ae(v))
	if ( abs_mvd_greater0_flag[0] ) == true then
	rexp("abs_mvd_greater1_flag[0]"                                              ) -- ae(v))
	if ( abs_mvd_greater0_flag[1] ) == true then
	rexp("abs_mvd_greater1_flag[1]"                                              ) -- ae(v))
	if ( abs_mvd_greater0_flag[0] ) == true then 
	if ( abs_mvd_greater1_flag[0] ) == true then
	rexp("abs_mvd_minus2[0]"                                              ) -- ae(v))
	rexp("mvd_sign_flag[0]"                                              ) -- ae(v))
	end
	if ( abs_mvd_greater0_flag[1] ) == true then 
	if ( abs_mvd_greater1_flag[1] ) == true then
	rexp("abs_mvd_minus2[1]"                                              ) -- ae(v))
	rexp("mvd_sign_flag[1]"                                              ) -- ae(v))
	end
	end

function transform_unit( x0, y0, xBase, yBase, log2TrafoSize, trafoDepth, blkIdx ) 
	                                              	log2TrafoSizeC = Max( 2, log2TrafoSize ? ( ChromaArrayType =  3 ? 0 : 1 ) )
	cbfDepthC = trafoDepth ? ( ChromaArrayType != 3 and log2TrafoSize =  2 ? 1 : 0 )
	xC = ( ChromaArrayType != 3 and log2TrafoSize =  2 ) ? xBase : x0
	yC = ( ChromaArrayType != 3 and log2TrafoSize =  2 ) ? yBase : y0
	cbfLuma  cbf_luma[x0][y0][trafoDepth]
	cbfChroma = cbf_cb[xC][yC][cbfDepthC] or cbf_cr[xC][yC][cbfDepthC] or ( ChromaArrayType =  2 and ( cbf_cb[xC][yC + ( 1 << log2TrafoSizeC )][cbfDepthC] or cbf_cr[xC][yC + ( 1 << log2TrafoSizeC )][cbfDepthC] ) )
	if ( cbfLuma or cbfChroma ) == true then 
	if ( cu_qp_delta_enabled_flag and !IsCuQpDeltaCoded ) == true then 
	rexp("cu_qp_delta_abs"                                              ) -- ae(v))
	if ( cu_qp_delta_abs ) == true then
	rexp("cu_qp_delta_sign_flag"                                              ) -- ae(v))
	end
	if ( cu_chroma_qp_offset_enabled_flag and cbfChroma and !cu_transquant_bypass_flag and !IsCuChromaQpOffsetCoded ) == true then 
	rexp("cu_chroma_qp_offset_flag"                                              ) -- ae(v))
	if ( cu_chroma_qp_offset_flag and chroma_qp_offset_list_len_minus1 > 0 ) == true then
	rexp("cu_chroma_qp_offset_idx"                                              ) -- ae(v))
	end
	if ( cbfLuma ) == true then
	residual_coding( x0, y0, log2TrafoSize, 0 )
	if ( log2TrafoSize > 2 or ChromaArrayType = = 3 ) == true then 
	if ( cross_component_prediction_enabled_flag and cbfLuma and ( CuPredMode[x0][y0] = = MODE_INTER or intra_chroma_pred_mode[x0][y0] = = 4 ) ) == true then
	cross_comp_pred( x0, y0, 0 )
	for  tIdx = 0; tIdx < ( ChromaArrayType = = 2 ? 2 : 1 ); tIdx++  do
	if ( cbf_cb[x0][y0 + ( tIdx << log2TrafoSizeC )][trafoDepth] ) == true then
	residual_coding( x0, y0 + ( tIdx << log2TrafoSizeC ), log2TrafoSizeC, 1 )
	if ( cross_component_prediction_enabled_flag and cbfLuma and ( CuPredMode[x0][y0] = = MODE_INTER or intra_chroma_pred_mode[x0][y0] = = 4 ) ) == true then
	cross_comp_pred( x0, y0, 1 )
	for  tIdx = 0; tIdx < ( ChromaArrayType = = 2 ? 2 : 1 ); tIdx++  do
	if ( cbf_cr[x0][y0 + ( tIdx << log2TrafoSizeC )][trafoDepth] ) == true then
	residual_coding( x0, y0 + ( tIdx << log2TrafoSizeC ), log2TrafoSizeC, 2 )
		elseif ( blkIdx = = 3 ) == true then 
	for  tIdx = 0; tIdx < ( ChromaArrayType = = 2 ? 2 : 1 ); tIdx++  do
	if ( cbf_cb[xBase][yBase + ( tIdx << log2TrafoSizeC )][trafoDepth ? 1] ) == true then
	residual_coding( xBase, yBase + ( tIdx << log2TrafoSizeC ), log2TrafoSize, 1 )
	for  tIdx = 0; tIdx < ( ChromaArrayType = = 2 ? 2 : 1 ); tIdx++  do
	if ( cbf_cr[xBase][yBase + ( tIdx << log2TrafoSizeC )][trafoDepth ? 1] ) == true then
	residual_coding( xBase, yBase + ( tIdx << log2TrafoSizeC ), log2TrafoSize, 2 )
	end
	end
	end
	                                              
function residual_coding( x0, y0, log2TrafoSize, cIdx ) 
	                                              	if ( transform_skip_enabled_flag and !cu_transquant_bypass_flag and ( log2TrafoSize <= Log2MaxTransformSkipSize ) ) == true then
	rexp("transform_skip_flag[x0][y0][cIdx]"                                              ) -- ae(v))
	if ( CuPredMode[x0][y0] = = MODE_INTER and explicit_rdpcm_enabled_flag and ( transform_skip_flag[x0][y0][cIdx] or cu_transquant_bypass_flag ) ) == true then 
	rexp("explicit_rdpcm_flag[x0][y0][cIdx]"                                              ) -- ae(v))
	if ( explicit_rdpcm_flag[x0][y0][cIdx] ) == true then
	rexp("explicit_rdpcm_dir_flag[x0][y0][cIdx]"                                              ) -- ae(v))
	end
	rexp("last_sig_coeff_x_prefix"                                              ) -- ae(v))
	rexp("last_sig_coeff_y_prefix"                                              ) -- ae(v))
	if ( last_sig_coeff_x_prefix > 3 ) == true then
	rexp("last_sig_coeff_x_suffix"                                              ) -- ae(v))
	if ( last_sig_coeff_y_prefix > 3 ) == true then
	rexp("last_sig_coeff_y_suffix"                                              ) -- ae(v))
	lastScanPos  16
	lastSubBlock  ( 1 << ( log2TrafoSize ? 2 ) ) * ( 1 << ( log2TrafoSize ? 2 ) ) ? 1
	escapeDataPresent  0
	do                                               	if ( lastScanPos = = 0 ) == true then 
	lastScanPos  16
	lastSubBlock? ?                                              	end
	lastScanPos? ?                                              	xS  ScanOrder[log2TrafoSize ? 2][scanIdx][lastSubBlock][0]
	yS  ScanOrder[log2TrafoSize ? 2][scanIdx][lastSubBlock][1]
	xC  ( xS << 2 ) + ScanOrder[2][scanIdx][lastScanPos][0]
	yC  ( yS << 2 ) + ScanOrder[2][scanIdx][lastScanPos][1]
	end while( ( xC != LastSignificantCoeffX ) or ( yC != LastSignificantCoeffY ) )
	for  i = lastSubBlock; i >= 0; i? ?  do 
	xS  ScanOrder[log2TrafoSize ? 2][scanIdx][i][0]
	yS  ScanOrder[log2TrafoSize ? 2][scanIdx][i][1]
	inferSbDcSigCoeffFlag  0
	if ( ( i < lastSubBlock ) and ( i > 0 ) ) == true then 
	rexp("coded_sub_block_flag[xS][yS]"                                              ) -- ae(v))
	inferSbDcSigCoeffFlag  1
	end
	for  n = ( i = = lastSubBlock ) ? lastScanPos ? 1 : 15; n >= 0; n? ?  do 
	xC  ( xS << 2 ) + ScanOrder[2][scanIdx][n][0]
	yC  ( yS << 2 ) + ScanOrder[2][scanIdx][n][1]
	if ( coded_sub_block_flag[xS][yS] and ( n > 0 or !inferSbDcSigCoeffFlag ) ) == true then 
	rexp("sig_coeff_flag[xC][yC]"                                              ) -- ae(v))
	if ( sig_coeff_flag[xC][yC] ) == true then
	inferSbDcSigCoeffFlag  0
	end
	end
	firstSigScanPos  16
	lastSigScanPos  ?1
	numGreater1Flag  0
	lastGreater1ScanPos  ?1
	for  n = 15; n >= 0; n? ?  do 
	xC  ( xS << 2 ) + ScanOrder[2][scanIdx][n][0]
	yC  ( yS << 2 ) + ScanOrder[2][scanIdx][n][1]
	if ( sig_coeff_flag[xC][yC] ) == true then 
	if ( numGreater1Flag < 8 ) == true then 
	rexp("coeff_abs_level_greater1_flag[n]"                                              ) -- ae(v))
	numGreater1Flag++                                              	if ( coeff_abs_level_greater1_flag[n] and lastGreater1ScanPos = = ?1 ) == true then
	lastGreater1ScanPos  n
	elseif ( coeff_abs_level_greater1_flag[n] ) == true then
	escapeDataPresent  1
	elseif
	escapeDataPresent  1
	if ( lastSigScanPos = = ?1 ) == true then
	lastSigScanPos  n
	firstSigScanPos  n
	end
	end
	if ( cu_transquant_bypass_flag or ( CuPredMode[x0][y0] = = MODE_INTRA and implicit_rdpcm_enabled_flag and transform_skip_flag[x0][y0][cIdx] and ( predModeIntra = = 10 or predModeIntra = = 26 ) ) or explicit_rdpcm_flag[x0][y0][cIdx] ) == true then
	signHidden  0
	else
	signHidden  lastSigScanPos ? firstSigScanPos > 3
	if ( lastGreater1ScanPos != ?1 ) == true then 
	rexp("coeff_abs_level_greater2_flag[lastGreater1ScanPos]"                                              ) -- ae(v))
	if ( coeff_abs_level_greater2_flag[lastGreater1ScanPos] ) == true then
	escapeDataPresent  1
	end
	for  n = 15; n >= 0; n? ?  do 
	xC  ( xS << 2 ) + ScanOrder[2][scanIdx][n][0]
	yC  ( yS << 2 ) + ScanOrder[2][scanIdx][n][1]
	if ( sig_coeff_flag[xC][yC] and ( !sign_data_hiding_enabled_flag or !signHidden or ( n != firstSigScanPos ) ) ) == true then
	rexp("coeff_sign_flag[n]"                                              ) -- ae(v))
	end
	numSigCoeff  0
	sumAbsLevel  0
	for  n = 15; n >= 0; n? ?  do 
	xC  ( xS << 2 ) + ScanOrder[2][scanIdx][n][0]
	yC  ( yS << 2 ) + ScanOrder[2][scanIdx][n][1]
	if ( sig_coeff_flag[xC][yC] ) == true then 
	baseLevel  1 + coeff_abs_level_greater1_flag[n] + coeff_abs_level_greater2_flag[n]
	if ( baseLevel = = ( ( numSigCoeff < 8 ) ? ( (n = = lastGreater1ScanPos) ? 3 : 2 ) : 1 ) ) == true then
	rexp("coeff_abs_level_remaining[n]"                                              ) -- ae(v))
	TransCoeffLevel[x0][y0][cIdx][xC][yC]  ( coeff_abs_level_remaining[n] + baseLevel ) * ( 1 ? 2 * coeff_sign_flag[n] )
	if ( sign_data_hiding_enabled_flag and signHidden ) == true then 
	sumAbsLevel + ( coeff_abs_level_remaining[n] + baseLevel )
	if ( ( n = = firstSigScanPos ) and ( ( sumAbsLevel % 2 ) = = 1 ) ) == true then
	TransCoeffLevel[x0][y0][cIdx][xC][yC]  ?TransCoeffLevel[x0][y0][cIdx][xC][yC]
	end
	numSigCoeff++                                              	end
	end
	end
	end

function cross_comp_pred( x0, y0, c ) 
	log2_res_scale_abs_plus1[c] ae(v)
	if ( log2_res_scale_abs_plus1[c] != 0 ) == true then
	rexp("res_scale_sign_flag[c]"                                              ) -- ae(v))
	end
	                                              
	                                              
	                                              
	                                              
	                                              
	                                              