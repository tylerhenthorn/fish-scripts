function record-audio -d "Record audio output and microphone input simultaneously"
    # Default output file
    set -l output_file $argv[1]
    if test -z "$output_file"
        set output_file "recording_"(date +%Y%m%d_%H%M%S)".mkv"
    end
    set -l output_dir "/home/user/Recordings/"

    # Get default sources
    set -l monitor (pactl get-default-sink).monitor
    set -l microphone (pactl get-default-source)

    echo "Recording configuration:"
    echo "  Output monitor: $monitor"
    echo "  Microphone: $microphone"
    echo "  Output file: $output_file"
    echo ""
    echo "Recording... Press Ctrl+C to stop."
    echo ""

    # Record both sources and mix them
    # -f pulse: use PulseAudio/PipeWire input
    # -i: input sources
    # -filter_complex amix: mix both audio streams
    # -ac 2: output stereo
    # -c:a libopus: use Opus codec (efficient, good quality)
    # -b:a 128k: bitrate
    ffmpeg -f pulse -i "$monitor" \
           -f pulse -i "$microphone" \
           -filter_complex "[0:a][1:a]amix=inputs=2:duration=longest:normalize=0[aout]" \
           -map "[aout]" \
           -ac 2 \
           -c:a libopus \
           -b:a 128k \
           "$output_dir/$output_file"

    echo ""
    echo "Recording saved to: $output_file"
end
