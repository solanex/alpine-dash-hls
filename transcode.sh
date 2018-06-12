#!/bin/sh

input_file="${1?Input file missing}"
# directoryname=$(dirname "${input_file}")
filename=$(basename "${input_file}")
filename="${filename%.*}"
frames=$(ffprobe -v error -select_streams v:0 -show_entries stream=nb_frames -of default=nokey=1:noprint_wrappers=1 "${input_file}")

# make folders
echo -e "\nCurrent video: ${input_file}\nDetected file name: ${filename}\nTotal # of frames: ${frames}" && mkdir -p "output/${filename}/thumbnails" && \

echo -e "\nCreating MPEG-DASH files" && \
# 1080p@CRF22
echo -e "Total # of frames: ${frames}\n\nCreating Full HD version (no upscaling, Step 1/4)" && \
ffmpeg -y -threads 0 -v error -stats -i "${input_file}" -an -c:v libx264 -x264opts 'keyint=24:min-keyint=24:no-scenecut' -profile:v high -level 4.0 -vf "scale=min'(1920,iw)':-4" -crf 22 -movflags faststart -write_tmcd 0 "output/${filename}/intermed_1080p.mp4" && \
# 720p@CRF22
echo -e "Creating HD version (no upscaling, Step 2/4)" && \
ffmpeg -y -threads 0 -v error -stats -i "${input_file}" -an -c:v libx264 -x264opts 'keyint=24:min-keyint=24:no-scenecut' -profile:v high -level 4.0 -vf "scale=min'(1280,iw)':-4" -crf 22 -movflags faststart -write_tmcd 0 "output/${filename}/intermed_720p.mp4" && \
# 480p@CRF22
echo -e "Creating DVD quality version (no upscaling, Step 3/4)" && \
ffmpeg -y -threads 0 -v error -stats -i "${input_file}" -an -c:v libx264 -x264opts 'keyint=24:min-keyint=24:no-scenecut' -profile:v high -level 4.0 -vf "scale=min'(720,iw)':-4" -crf 22 -movflags faststart -write_tmcd 0 "output/${filename}/intermed_480p.mp4" && \
# 128k AAC audio only
echo -e "Creating audio only version (Step 4/4)" && \
ffmpeg -y -threads 0 -v error -stats -i "${input_file}" -vn -c:a aac -b:a 128k "output/${filename}/audio_128k.m4a" && \

# Create MPEG-DASH files (segments & mpd-playlist)
echo -e "\nCreating MPEG-DASH files & MPD-playlist" && \
MP4Box -dash 2000 -rap -frag-rap -url-template -dash-profile onDemand -segment-name 'segment_$RepresentationID$' -out "output/${filename}/playlist.mpd" "output/${filename}/intermed_1080p.mp4" "output/${filename}/intermed_720p.mp4" "output/${filename}/intermed_480p.mp4" "output/${filename}/audio_128k.m4a" && \

# Create HLS playlists for each quality level
echo -e "\nCreating HLS files (needed for Safari on iOS, Safari on Mac is already compatible with MPEG-DASH files)" && \
echo -e "Total # of frames: ${frames}\n\nCreating Full HD version (no upscaling, Step 1/4)" && \
ffmpeg -y -threads 0 -v error -stats -i "output/${filename}/intermed_1080p.mp4" -i "output/${filename}/audio_128k.m4a" -map 0:v:0 -map 1:a:0 -shortest -acodec copy -vcodec copy -hls_time 2 -hls_list_size 0 -hls_flags single_file "output/${filename}/segment_1.m3u8" && \
echo -e "Creating HD version (no upscaling, Step 2/4)" && \
ffmpeg -y -threads 0 -v error -stats -i "output/${filename}/intermed_720p.mp4" -i "output/${filename}/audio_128k.m4a" -map 0:v:0 -map 1:a:0 -shortest -acodec copy -vcodec copy -hls_time 2 -hls_list_size 0 -hls_flags single_file "output/${filename}/segment_2.m3u8" && \
echo -e "Creating DVD quality version (no upscaling, Step 3/4)" && \
ffmpeg -y -threads 0 -v error -stats -i "output/${filename}/intermed_480p.mp4" -i "output/${filename}/audio_128k.m4a" -map 0:v:0 -map 1:a:0 -shortest -acodec copy -vcodec copy -hls_time 2 -hls_list_size 0 -hls_flags single_file "output/${filename}/segment_3.m3u8" && \
echo -e "Creating audio only version (Step 4/4)" && \
ffmpeg -y -threads 0 -v error -stats -i "output/${filename}/audio_128k.m4a" -acodec copy -vcodec copy -hls_time 2 -hls_list_size 0 -hls_flags single_file "output/${filename}/segment_4.m3u8" && \

# Transform MPD-Master-Playlist to M3U8-Master-Playlist
echo -e "\nCreating master M3U8-playlist for HLS" && \
xsltproc --stringparam run_id "segment" /app/mpd-to-m3u8/mpd_to_hls.xsl "output/${filename}/playlist.mpd" > "output/${filename}/playlist.m3u8" && \

# Cleanup
echo -e "\nCleanup of intermediary files" && \
rm "output/${filename}/intermed_1080p.mp4" "output/${filename}/intermed_720p.mp4" "output/${filename}/intermed_480p.mp4" "output/${filename}/audio_128k.m4a";

# Set permissions for newly created files and folders matching the video file's permissions
echo -e "\nSetting permissions for all created files and folders & finishing";
chown -R `stat -c "%u:%g" "${input_file}"` output;
