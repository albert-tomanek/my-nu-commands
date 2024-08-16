module news {
    def get_articles [] {
        http get https://lemmy.world/feeds/c/news.xml?sort=Hot |from xml|get content.content.0| where tag == item |get content
    }

    def print_titles [] {
        get_articles | each {|z| $z | where tag == title| get content.0.content.0 }
    }

    export def list [num :int = -1] {
        if $num < 0 {
            print_titles
        } else {
            let url = _get_articles | get $num | where tag == link | get content.0.content.0
            w3m $url
        }
    }
}
use news;
