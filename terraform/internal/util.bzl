def merge_filemap_dict(a, b):
    """
    Return a combined dict of A and B, eliminating duplicates.
    Error if multiple src Files are associated with a single tgt path
    """
    out = {}
    out.update(a)
    out.update(b)
    return out