$env.YT_SELECTED_URL = null;

module yt {
    # Commands

    # Search YouTube for a video. Selection will be remembered on invocation of subsequent commands.
    export def --env search [
        phrase: string,
        n: int = 6,     # Number of results to find
        --table,        # Don't select result; return table.
        # --lucky,        # Select the first result
    ] {
        let res = (yt-dlp $"ytsearch($n):($phrase)" --get-title --get-id) | split row "\n" | group 2 | each {|a| {title: $a.0, id: $a.1}};

        if not $table {
            #let id = ($res|input list --display {|| get title}|get id);
            let id = ($res|input list|get id);
            $env.YT_SELECTED_URL = $"https://youtu.be/($id)";
        } else {
            return $res;
        }
    }

    # Browse the comments of a YouTube video. Pipe to `explore` and navigate with Enter key.
    export def comments [url?: string, --id, --no-wrap] {
        # Download video info into temp dir if not already cached
        let cwd = $"/tmp/.video_cache_(get_selected $url | parse_id)"

        if not ($cwd + "/video.info.json" | path exists) {
            mkdir $cwd
            yt-dlp --write-comments --skip-download (get_selected $url) -o $"($cwd)/video"
        }

        # Parse
        return (
            open $"($cwd)/video.info.json" |
            get comments |
            select text id parent like_count? timestamp author_id |
            update timestamp {|rec| $rec.timestamp|into string|into datetime -f %s} |
            update like_count? {|rec| if $rec.like_count == null { 0 } else { $rec.like_count } } | # Is `null` where 0 likes.
            if not $no_wrap { update text {|rec| $rec.text|str replace '\n' ""|str trim|split chars|group ((term size).columns * 2 // 3)|each {|| str join}|str join "\n" } } |    # Artificially add newlines because they seem to be missing.
            do { unflatten_comments $in $id } |
            if not $id { reject id }        # Not needed any more
        );
    }

    # Filter output of `yt comments`. Again, pipe this to `explore`.
    export def "comments search" [regex: string] {
        where {|toplevel| $toplevel.text =~ $regex or ($toplevel.replies | any {$in.text =~ $regex})}
    }

    export def play [url?: string] {
        let cwd = $"/tmp/.video_cache_(get_selected $url | parse_id)"
        mkdir $cwd

        if (ls $cwd|where name =~ downloaded|length) == 0 {
            yt-dlp -f18 (get_selected $url) -o ($cwd + "/downloaded")
        }

        mpv --no-config --vo=tct $"($cwd)/downloaded*"
    }

    export def "download" [url?: string] {

    }

    export def "download audio" [url?: string] {
        yt-dlp --extract-audio -f140 (get_selected $url)
    }

    # Helper functions
    def get_selected [alt?: string] -> string {
        if $env.YT_SELECTED_URL != null {
            return $env.YT_SELECTED_URL;
        } else if $alt != null {
            return $alt;
        } else {
            error make {msg: "No youtube video selected."}
        }
    }

    def parse_id [] -> string {
        parse -r "(?:youtube\\.com\\/(?:[^\\/]+\\/.+\\/|(?:v|e(?:mbed)?)\\/|.*[?&]v=)|youtu\\.be\\/)([^\"&?\\/\\s]{11})"|get 0.capture0
    }

    def unflatten_comments [comments, id: bool] {
        $comments |
        where parent == root |  # Don't keep any non-toplevel comments
        reject parent |         # Now redundant
        par-each {|r| {replies: (
            $comments |
                where parent == $r.id |
                reject parent | # Now redundant
                if not $id { reject id } |
                sort-by timestamp
        ), ...$r}} |
        sort-by -r like_count
    }
}
use yt;
