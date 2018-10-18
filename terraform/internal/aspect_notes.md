
### image_resolver
- Embed deterministic digest during build, _without_ publishing
- Expose image info in Provider
- Use aspect on publisher/integrationtest deps to collect transitive image info
- Push transitive images

### Inputs
- publisher
  - same as image_resolver
- digest calculator
  - same as image_resolver

### Approach
Essentially, use 95% "image_resolver.py" for both embedding & publishing
- When embedding, do just: `docker_name.Digest('{repository}@{digest}'.format(repository=name_to_publish.as_repository(), digest=v2_2_img.digest()))`
- When publishing, do just: `session.upload(v2_2_img)`

### Impl
image_resolver:
- `ImagePublishInfo = provider(resolver_configs=[<File>], runfiles=<Depset>)` (or just nested struct(s) of the configs?)
aspect: (or could manually propagate 'ImagePublishInfo' instead of using aspect??)
- Propagate along '*' attributes
- I guess do `hasattr()` over `dir(ctx.rule.attr)`??
  - Only `if ImagePublishInfo not in target:`
  - Could also query/genquery for transitive deps by rule name (ie image_resolver or tf_k8s_manifest)
  - ^ but maybe not bc kinda messy?
- _wrong:_ Actually, **Don't need to iterate over rule attrs**--just check `if ImagePublishInfo in target:` ??
image_publisher:
- helper function for use by publishers (eg github_release_publisher)
- creates executable file to publish images
- args: `image_publisher(ctx, output, images_to_publish=[<ImagePublishInfo>])`
- returns `runfiles<Depset>`

### Types/kinds
- ImageSpec (resolver):
    - name
    - tarball (used as 'legacy_base')
    - config (required when using layer/digest)
    - digest, layer (comma separated lists & must be same length)
- ImageConfig