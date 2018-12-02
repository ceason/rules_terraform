

ContentAddressableFileInfo = provider(
    fields = {
        "url":"<File> containing the published url of the file.",
        "file": "<File> to be published.",
    }
)

EmbeddedContentInfo = provider(
    fields = {
        "content_publishers":"<Depset> of executable <Target>s that will publish content when run.",
    }
)