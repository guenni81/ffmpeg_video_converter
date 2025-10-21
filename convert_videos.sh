#!/bin/bash
# =====================================
# Mac mini M4/Pro FFmpeg Converting tool
# =====================================

shopt -s globstar nullglob

function ReadSettingsFromUser() {
    ReadInputDirectorySettings
    ReadOutputDirectorySettings
    ReadResolutionSettings
    ReadFramesPerSecondsSettings
    ReadBitDepthResolutionSettings
    ReadQualitySettings
    ReadLanguageSelectionSettings
    ReadAudioFormatsSelectionSettings
}

function ReadInputDirectorySettings() {
  echo "Set video input directory:"
  read INPUT_DIR
  if [[ -z $INPUT_DIR ]]; 
  then
    ech0 "Video Input directory not set!";
    exit 1;
  fi
}
  
function ReadOutputDirectorySettings() {
  echo "Set video output directory (default: video_input/video_output):"
  read OUTPUT_DIR
  [[ -z $OUTPUT_DIR ]] && OUTPUT_DIR="$INPUT_DIR/video_output"
} 
 
function ReadResolutionSettings() { 
  local RESOLUTION_CHOICE
  echo "Select Resolution: 1=1080p, 2=4K: (default=1080p):"
  read RESOLUTION_CHOICE
  [[ -z "$RESOLUTION_CHOICE" ]] && RESOLUTION_CHOICE=1
  
  if [[ "$RESOLUTION_CHOICE" == 1 ]]; then
      RESOLUTION="1920:1080"; 
    else 
      RESOLUTION="3840:2160";
  fi
}
  
function ReadFramesPerSecondsSettings() {
  echo "Framerate (FPS, empty=automatic detected):"
  read FPS
}
  
function ReadBitDepthResolutionSettings() {
  local BITDEPTH
  echo "Bit-depth (8bit or 10bit, default=8bit):"
  read BITDEPTH
  [[ -z "$BITDEPTH" ]] && BITDEPTH="8bit"
  
  if [[ "$BITDEPTH" == "10" || "$BITDEPTH" == "10bit" ]]; then
      TONE_MAPPING_FILTER=""
      TONE_MAPPING_PARAMETERS=""
      PIXEL_FORMAT="yuv420p10le"
      PROFILE="main10"
  else
      TONE_MAPPING_FILTER=",format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p"
      TONE_MAPPING_PARAMETERS="-color_primaries bt709 -color_trc bt709 -colorspace bt709"
      PIXEL_FORMAT="yuv420p"
      PROFILE="main"
  fi  
}
  
function ReadQualitySettings() {  
  echo "Quality (Q-Parameter, Standard=65):"
  read QUALITY
  [[ -z "$QUALITY" ]] && QUALITY=65
}
 
function ReadLanguageSelectionSettings() {
  local LANGUAGE_CHOICE
  echo "Language(s) for audio and subtitles (multiple languages separated by commas, default=ger):"
  read LANGUAGE_CHOICE
  [[ -z "$LANGUAGE_CHOICE" ]] && LANGUAGE_CHOICE="ger"
  IFS=',' read -r -a LANGUAGES <<< "$LANGUAGE_CHOICE"
}

function ReadAudioFormatsSelectionSettings() {  
  local AUDIO_FORMAT_INPUT
  echo "Audio format(s) to be imported (multiple formats separated by commas)(default: ac3):"
  read AUDIO_FORMAT_INPUT
  [[ -z "$AUDIO_FORMAT_INPUT"  ]] && AUDIO_FORMAT_INPUT="ac3" 
  IFS=',' read -r -a AUDIO_FORMATS <<< "$AUDIO_FORMAT_INPUT"
}

function MapAudioCodec() {
    local video_file
    local audio_count
    local audio_found
    AUDIO_MAP=()
    AUDIO_CODEC=()
    
    video_file=$1
    audio_count=$(ffprobe -v error -select_streams a -show_entries stream=index,codec_name,stream_tags=language -of csv=p=0 "$video_file" | wc -l)
    audio_found=0
    
    for i in $(seq 0 $((audio_count-1))); do
        codec=$(ffprobe -v error -select_streams a:$i -show_entries stream=codec_name -of csv=p=0 "$video_file")
        lang=$(ffprobe -v error -select_streams a:$i -show_entries stream_tags=language -of csv=p=0 "$video_file")
        
        for l in "${LANGUAGES[@]}"; do
          if [[ "$lang" == "$l" ]]; then
           # Check whether codec is included in desired format
            for fmt in "${AUDIO_FORMATS[@]}"; do
                if [[ "$codec" == "$fmt" ]]; then
                    audio_found=1
                    AUDIO_MAP+=("-map" "0:a:$i")
                    break
                fi
            done
          fi
        done
    done

    # If no track is available in the desired language, create one automatically.
    if [[ $audio_found -eq 0 ]]; then
        echo "ℹ️ No audio track found in ${LANGUAGES[*]}. Convert first audio track to ac3"
        AUDIO_MAP+=("-map" "0:a:0")
        echo "###${#AUDIO_FORMATS[@]}###"
        AUDIO_CODEC+=("-c:a:${#AUDIO_CODEC[@]}" "ac3")
      else
        AUDIO_CODEC+=("-c:a" "copy")
    fi
}

function MapSubtitles() {
  local video_file
  local subtitles_count
  SUBTITLES_MAP=()
  SUBTITLES_PARAMETER=()
  
  video_file=$1
  subtitles_count=$(ffprobe -loglevel error -select_streams s -show_entries stream=index:stream_tags=language -of csv=p=0 "$video_file" | wc -l)
  
  for i in $(seq 0 $((subtitles_count-1))); do
    lang=$(ffprobe -v error -select_streams s:$i -show_entries stream_tags=language -of csv=p=0 "$video_file")
    for l in "${LANGUAGES[@]}"; do
      if [[ "$lang" == "$l" ]]; then
        SUBTITLES_MAP+=("-map" "0:s:$i")
      fi
    done
  done
  
  if [ ${#SUBTITLES_MAP[@]} -gt 0 ]; then
    SUBTITLES_PARAMETER+=("-c:s" "copy")
  fi
}

function FillFpsFromOriginalMovieFile() {
  local video_file
  video_file=$1
  
  if [[ -z $FPS ]]; then
    local fps_str
    fps_str=$(ffprobe -v 0 -select_streams v:0 -of csv=p=0 -show_entries stream=r_frame_rate "$video_file")
    if [[ -n "$fps_str" ]]; then
        FPS=$(echo "scale=2; $fps_str" | bc -l 2>/dev/null)
    fi
    [[ -z "$fps" ]] && fps=30
  fi
}

function RunFFMPeg() {
  local video_file
  local video_temp_file
  local video_output_file
  video_file=$1
  video_temp_file=$2
  video_output_file=$3

  ffmpeg -hide_banner -y -i "$video_file" \
    -vf "scale=${RESOLUTION},zscale=t=linear:npl=100${TONE_MAPPING_FILTER}" \
    -map 0:v:0 -c:v hevc_videotoolbox -profile:v $PROFILE -pix_fmt $PIXEL_FORMAT -q:v $QUALITY  \
    $([ -n "$FPS" ] && echo "-r $FPS") \
    ${TONE_MAPPING_PARAMETERS} \
    "${AUDIO_MAP[@]}" "${AUDIO_CODEC[@]}" "${SUBTITLES_MAP[@]}" "${SUBTITLES_PARAMETER[@]}"  \
    -tag:v hev1 \
    "$video_temp_file"
    
    if [ $? -ne 0 ]; then
        exit 1;
    fi
    
    # ignored pgs subtitles
    ffmpeg -y -i "$video_temp_file" -c copy -bsf:v hevc_mp4toannexb "$video_output_file"
}

function ProcessMovieFiles() {
# --- Processing ---
  for INPUT_FILE in "$INPUT_DIR"/**/*.{mp4,mkv}; do
    [ -f "$INPUT_FILE" ] || continue

    BASE="$(basename "$INPUT_FILE")"
    FILENAME="${BASE%.*}"
    DIRECTORY="$(dirname "$INPUT_FILE")"
    DIRECTORY_NAME="${DIRECTORY#"${INPUT_DIR%/}"}"
    MKV_FINAL_OUT_DIRECTORY="$OUTPUT_DIR${DIRECTORY_NAME}"
    MKV_TEMP_OUT="$MKV_FINAL_OUT_DIRECTORY/${FILENAME}_tmp.mkv"
    MKV_FINAL_OUT="$MKV_FINAL_OUT_DIRECTORY/${FILENAME}_HVEC.mkv"
    
    if [[ ! -d $MKV_FINAL_OUT_DIRECTORY ]]; then
      echo "Create Directory $MKV_FINAL_OUT_DIRECTORY"
      mkdir -p "$MKV_FINAL_OUT_DIRECTORY"
    fi
    
    echo "Processing: $BASE"

    FillFpsFromOriginalMovieFile "$INPUT_FILE"
    MapAudioCodec "$INPUT_FILE"
    MapSubtitles "$INPUT_FILE"

    RunFFMPeg "$INPUT_FILE" "$MKV_TEMP_OUT" "$MKV_FINAL_OUT"
    if [ $? -ne 0 ]; then
        echo "❌ MP4-Encoding failed: $BASE"
    fi
    rm "$MKV_TEMP_OUT"

  done  
}

function main() {
    ReadSettingsFromUser
    ProcessMovieFiles
}

main
