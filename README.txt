Buffersaurus is a plugin for searching and indexing the contents of buffers
for regular expression patterns or collections of regular expression patterns.
Results are displayed in separate buffer, and can be (optionally) viewed with
user-specifiable lines of context (i.e., a number of lines before and/or after
the line matching the search pattern) or filtered for specific patterns.

Global commands provided include (among others):

  :Bsgrep[!] {pattern}

    Search all buffers (or just current buffer if "!" given) for regular
    expression pattern, {pattern}.

  :Bstoc[!]

    Construct a "table-of-contents" consisting of filetype-dependent
    "important" patterns (e.g. class and method/function definitions).

Other commands include those for filtering results, jumping to next/previous
matching line without opening the catalog, searching for special user-defined
terms (":Bsterm") etc.

The results list can be browsed/navigated using all the usual Vim movement
commands. Selected lines can be opened in the previous window, a new window
split (vertical or horizontal), or a new tab page. Context can be toggled (i.e.
show a user-specified number of lines before or after the matching line).
Results are grouped and sorted by filename, and then by line number, but can
also be ungrouped and sorted lexically.

Search and replace operations (using the ":Bsreplace" command, or "R" key
mapping), or execution of arbitrary commands ("x" or "X" key mapping),
can also be carried out on matched or contexted lines can be carried out

Detailed usage description is given in the help file, which can be viewed
on-line here:

    http://github.com/jeetsukumaran/vim-buffersaurus/blob/master/doc/buffersaurus.txt

Source code repository can be found here:

    http://github.com/jeetsukumaran/vim-buffersaurus

