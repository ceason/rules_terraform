

ContentAddressableFileInfo = provider(
    fields = {
        "url":"File containing the published url of the file",
        "file": "File to be published",
    }
)

EmbeddedContentInfo = provider(
    fields = {
        "container_pushes":"Depset of container push targets",
        "content_addressable_files":"Depset of content addressable file targets",
    }
)