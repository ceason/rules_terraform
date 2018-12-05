

FileUploaderInfo = provider(
    fields = {
        "url":"<File> containing the published location of the content.",
        #"executable":"Executable <File> which publishes the content when run.",
        #"runfiles":"<Runfiles> necessary for executable.",
    }
)

EmbeddedContentInfo = provider(
    fields = {
        "content_publishers":"<Depset> of executable <Target>s that will publish content when run.",
    }
)