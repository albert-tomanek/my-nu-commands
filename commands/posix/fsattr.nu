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
    let value = attr get $path|get -i user.baloo.rating;
    return (if ($value|is-empty) { null } else { $value|into int });
}

# Set the rating for a file
def 'rate' [path, val: int] {   # FIXME: This may clash with something
    attr set $path 'user.baloo.rating' ($val|into string)
}

# TODO: Consider adding glob support, https://www.nushell.sh/book/moving_around.html#glob-patterns-wildcards

# def --wrapped 'ls attr' [...rest] {

# Pipe the output of 'ls' into this to see attributes too.
def 'with attr' [] {
    $in
    | insert rating {|row| rating $row.name}
    | insert tags   {|row| tags list $row.name}
}
