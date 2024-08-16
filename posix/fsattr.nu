def 'attr get' [path] {
    let output = getfattr -dm '' -- $path;

    if not ($output|is-empty) {
        $output|from toml
    } else {
        {}
    }
}

def 'attr set' [path, name, value] {
    setfattr -n $name -v $value -- $path
}

def 'attr remove' [path, name] {
    setfattr -x $name -- $path
}

# List all the tags in this directory
def 'tags here' [path = '.'] {
    ls $path | reduce --fold [] {|it, acc| $acc | append (try {tags list $it.name}) }|uniq
}

# List all the tags on a file
def 'tags list' [path] {
    let tags = attr get $path|get -i user.xdg.tags;

    if $tags != null {
        $tags | split row ','
    } else {
        []
    }
}

# Add a tag to a file
def 'tags add' [path, name] {
    let existing = tags list $path;
    attr set $path 'user.xdg.tags' ($existing | append $name | str join ',');
}

# Remove a tag from a file
def 'tags remove' [path, name] {
    let existing = tags list $path;
    let indices  = ($existing|enumerate|where item == $name|get index);
    let result   = if not ($indices|is-empty) { $existing|drop nth ($indices|first) } else { $existing };
    attr set $path 'user.xdg.tags' ($result | str join ',');
}

# Get the rating for a file
def rating [path] -> int {
    let score = attr get $path|get -i user.baloo.rating;
    return (if ($score|is-empty) { null } else { $score|into int });
}

# Set the rating for a file
def 'rating set' [
    path,
    score: int  # Must be between 1 and 10.
] {
    attr set $path 'user.baloo.rating' ($score|into string)
}

alias rate = rating set;    # FIXME: Name may clash with something

# Remove the rating from a file
def 'rating remove' [path] {
    attr remove $path 'user.baloo.rating'
}

# Sets a file's comment if a message is provided, else gets it.
def comment [path, message?] {
    if ($message|is-empty) {
        return (attr get $path|get -i user.xdg.comment)
    } else {
        attr set $path 'user.xdg.comment' $message;
    }
}

# TODO: Consider adding glob support, https://www.nushell.sh/book/moving_around.html#glob-patterns-wildcards

# def --wrapped 'ls attr' [...rest] {

# Pipe the output of 'ls' into this to see attributes too.
def 'with attr' [] {
    $in
    | insert rating  {|row| rating $row.name}
    | insert tags    {|row| tags list $row.name}
    | insert comment {|row| comment $row.name}
}
