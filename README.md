
# Getting Started

### `WORKSPACE` file
```python
git_repository(
    name = "rules_terraform",
    commit = "27c68a2b75947967a983afa9afe09db79d190bfc", # 2018-12-19 13:07:38 -0500
    remote = "https://github.com/ceason/rules_terraform.git",
)

load("@rules_terraform//terraform:dependencies.bzl", "terraform_repositories")

terraform_repositories()
```

### Usage Examples
- [`//examples`](examples/)
- [`//examples/publishing/BUILD`](examples/publishing/BUILD) (experimental)

# Rules

- [terraform_module](#terraform_module)
- [terraform_workspace](#terraform_workspace)
- [terraform_integration_test](#terraform_integration_test)
- [terraform_provider](#terraform_provider)

### Experimental

- [terraform_k8s_manifest](#terraform_k8s_manifest)
- [embedded_reference](#embedded_reference)
- [file_uploader](#file_uploader)
- [ghrelease_publisher](#ghrelease_publisher)
- [ghrelease_assets](#ghrelease_assets)
- [ghrelease_test_suite](#ghrelease_test_suite)

<a name="#terraform_module"></a>
## terraform_module

<pre>
terraform_module(<a href="#terraform_module-name">name</a>, <a href="#terraform_module-data">data</a>, <a href="#terraform_module-deps">deps</a>, <a href="#terraform_module-embed">embed</a>, <a href="#terraform_module-modulepath">modulepath</a>, <a href="#terraform_module-plugins">plugins</a>, <a href="#terraform_module-srcs">srcs</a>)
</pre>



### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="terraform_module-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="terraform_module-data">
      <td><code>data</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
      </td>
    </tr>
    <tr id="terraform_module-deps">
      <td><code>deps</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
      </td>
    </tr>
    <tr id="terraform_module-embed">
      <td><code>embed</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
        <p>
          Merge the content of other <terraform_module>s (or other 'ModuleInfo' providing deps) into this one.
        </p>
      </td>
    </tr>
    <tr id="terraform_module-modulepath">
      <td><code>modulepath</code></td>
      <td>
        String; optional
      </td>
    </tr>
    <tr id="terraform_module-plugins">
      <td><code>plugins</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
        <p>
          Custom Terraform plugins that this module requires.
        </p>
      </td>
    </tr>
    <tr id="terraform_module-srcs">
      <td><code>srcs</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
      </td>
    </tr>
  </tbody>
</table>


<a name="#terraform_workspace"></a>
## terraform_workspace

<pre>
terraform_workspace(<a href="#terraform_workspace-name">name</a>, <a href="#terraform_workspace-data">data</a>, <a href="#terraform_workspace-deps">deps</a>, <a href="#terraform_workspace-embed">embed</a>, <a href="#terraform_workspace-plugins">plugins</a>, <a href="#terraform_workspace-srcs">srcs</a>)
</pre>



### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="terraform_workspace-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="terraform_workspace-data">
      <td><code>data</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
      </td>
    </tr>
    <tr id="terraform_workspace-deps">
      <td><code>deps</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
      </td>
    </tr>
    <tr id="terraform_workspace-embed">
      <td><code>embed</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
        <p>
          Merge the content of other <terraform_module>s (or other 'ModuleInfo' providing deps) into this one.
        </p>
      </td>
    </tr>
    <tr id="terraform_workspace-plugins">
      <td><code>plugins</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
        <p>
          Custom Terraform plugins that this workspace requires.
        </p>
      </td>
    </tr>
    <tr id="terraform_workspace-srcs">
      <td><code>srcs</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
      </td>
    </tr>
  </tbody>
</table>


<a name="#terraform_integration_test"></a>
## terraform_integration_test

<pre>
terraform_integration_test(<a href="#terraform_integration_test-name">name</a>, <a href="#terraform_integration_test-srctest">srctest</a>, <a href="#terraform_integration_test-terraform_workspace">terraform_workspace</a>)
</pre>



### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="terraform_integration_test-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="terraform_integration_test-srctest">
      <td><code>srctest</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; required
        <p>
          Label of source test to wrap
        </p>
      </td>
    </tr>
    <tr id="terraform_integration_test-terraform_workspace">
      <td><code>terraform_workspace</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; required
        <p>
          TF Workspace to spin up before testing & tear down after testing.
        </p>
      </td>
    </tr>
  </tbody>
</table>


<a name="#terraform_provider"></a>
## terraform_provider

<pre>
terraform_provider(<a href="#terraform_provider-name">name</a>, <a href="#terraform_provider-file">file</a>, <a href="#terraform_provider-provider_name">provider_name</a>, <a href="#terraform_provider-version">version</a>)
</pre>



### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="terraform_provider-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="terraform_provider-file">
      <td><code>file</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
      </td>
    </tr>
    <tr id="terraform_provider-provider_name">
      <td><code>provider_name</code></td>
      <td>
        String; optional
        <p>
          Name of terraform provider.
        </p>
      </td>
    </tr>
    <tr id="terraform_provider-version">
      <td><code>version</code></td>
      <td>
        String; optional
      </td>
    </tr>
  </tbody>
</table>


<a name="#terraform_k8s_manifest"></a>
## terraform_k8s_manifest

<pre>
terraform_k8s_manifest(<a href="#terraform_k8s_manifest-name">name</a>, <a href="#terraform_k8s_manifest-deps">deps</a>, <a href="#terraform_k8s_manifest-srcs">srcs</a>)
</pre>



### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="terraform_k8s_manifest-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="terraform_k8s_manifest-deps">
      <td><code>deps</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
        <p>
          Embeddable targets (eg container_push).
        </p>
      </td>
    </tr>
    <tr id="terraform_k8s_manifest-srcs">
      <td><code>srcs</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
      </td>
    </tr>
  </tbody>
</table>


<a name="#embedded_reference"></a>
## embedded_reference

<pre>
embedded_reference(<a href="#embedded_reference-name">name</a>, <a href="#embedded_reference-deps">deps</a>, <a href="#embedded_reference-out">out</a>, <a href="#embedded_reference-src">src</a>)
</pre>



### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="embedded_reference-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="embedded_reference-deps">
      <td><code>deps</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; required
        <p>
          Embeddable targets (eg container_push, content_addressable_file, etc).
        </p>
      </td>
    </tr>
    <tr id="embedded_reference-out">
      <td><code>out</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; required
        <p>
          Single output file.
        </p>
      </td>
    </tr>
    <tr id="embedded_reference-src">
      <td><code>src</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; required
        <p>
          Single template file.
        </p>
      </td>
    </tr>
  </tbody>
</table>


<a name="#file_uploader"></a>
## file_uploader

<pre>
file_uploader(<a href="#file_uploader-name">name</a>, <a href="#file_uploader-sha256">sha256</a>, <a href="#file_uploader-src">src</a>, <a href="#file_uploader-url_prefix">url_prefix</a>)
</pre>



### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="file_uploader-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="file_uploader-sha256">
      <td><code>sha256</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; optional
      </td>
    </tr>
    <tr id="file_uploader-src">
      <td><code>src</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>; required
      </td>
    </tr>
    <tr id="file_uploader-url_prefix">
      <td><code>url_prefix</code></td>
      <td>
        String; required
        <p>
          Prefix of URL where this file should be published (eg 's3://my-bucket-name/')
        </p>
      </td>
    </tr>
  </tbody>
</table>


<a name="#ghrelease_publisher"></a>
## ghrelease_publisher

<pre>
ghrelease_publisher(<a href="#ghrelease_publisher-name">name</a>, <a href="#ghrelease_publisher-branch">branch</a>, <a href="#ghrelease_publisher-deps">deps</a>, <a href="#ghrelease_publisher-docs">docs</a>, <a href="#ghrelease_publisher-docs_branch">docs_branch</a>, <a href="#ghrelease_publisher-semver_env_var">semver_env_var</a>, <a href="#ghrelease_publisher-version">version</a>)
</pre>



### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="ghrelease_publisher-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="ghrelease_publisher-branch">
      <td><code>branch</code></td>
      <td>
        String; optional
      </td>
    </tr>
    <tr id="ghrelease_publisher-deps">
      <td><code>deps</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
      </td>
    </tr>
    <tr id="ghrelease_publisher-docs">
      <td><code>docs</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
      </td>
    </tr>
    <tr id="ghrelease_publisher-docs_branch">
      <td><code>docs_branch</code></td>
      <td>
        String; optional
      </td>
    </tr>
    <tr id="ghrelease_publisher-semver_env_var">
      <td><code>semver_env_var</code></td>
      <td>
        String; optional
        <p>
          UNIMPLEMENTED. Expose the SEMVER via this environment variable (eg for use in stamping via --workspace_status_command).
        </p>
      </td>
    </tr>
    <tr id="ghrelease_publisher-version">
      <td><code>version</code></td>
      <td>
        String; required
      </td>
    </tr>
  </tbody>
</table>


<a name="#ghrelease_assets"></a>
## ghrelease_assets

<pre>
ghrelease_assets(<a href="#ghrelease_assets-name">name</a>, <a href="#ghrelease_assets-bazel_flags">bazel_flags</a>, <a href="#ghrelease_assets-data">data</a>, <a href="#ghrelease_assets-env">env</a>)
</pre>



### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="ghrelease_assets-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="ghrelease_assets-bazel_flags">
      <td><code>bazel_flags</code></td>
      <td>
        List of strings; optional
      </td>
    </tr>
    <tr id="ghrelease_assets-data">
      <td><code>data</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a>; optional
      </td>
    </tr>
    <tr id="ghrelease_assets-env">
      <td><code>env</code></td>
      <td>
        <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a>; optional
      </td>
    </tr>
  </tbody>
</table>


<a name="#ghrelease_test_suite"></a>
## ghrelease_test_suite

<pre>
ghrelease_test_suite(<a href="#ghrelease_test_suite-name">name</a>, <a href="#ghrelease_test_suite-bazel_flags">bazel_flags</a>, <a href="#ghrelease_test_suite-env">env</a>, <a href="#ghrelease_test_suite-tests">tests</a>)
</pre>



### Attributes

<table class="params-table">
  <colgroup>
    <col class="col-param" />
    <col class="col-description" />
  </colgroup>
  <tbody>
    <tr id="ghrelease_test_suite-name">
      <td><code>name</code></td>
      <td>
        <a href="https://bazel.build/docs/build-ref.html#name">Name</a>; required
        <p>
          A unique name for this target.
        </p>
      </td>
    </tr>
    <tr id="ghrelease_test_suite-bazel_flags">
      <td><code>bazel_flags</code></td>
      <td>
        List of strings; optional
      </td>
    </tr>
    <tr id="ghrelease_test_suite-env">
      <td><code>env</code></td>
      <td>
        <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a>; optional
      </td>
    </tr>
    <tr id="ghrelease_test_suite-tests">
      <td><code>tests</code></td>
      <td>
        List of strings; optional
      </td>
    </tr>
  </tbody>
</table>


