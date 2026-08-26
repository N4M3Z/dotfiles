# tuicr

> Review local changes or GitHub pull requests in a terminal interface.
> The local shell wrapper reviews uncommitted changes when the tree is dirty, otherwise the latest commit.
> More information: <https://tuicr.dev/>.

- Review the working tree when dirty, otherwise the latest commit (wrapper default):

`tuicr`

- Review uncommitted working-tree changes:

`tuicr -w`

- Review a revision range:

`tuicr -r {{main..HEAD}}`

- Review every tracked file in the repository:

`tuicr --all-files`

- Filter the diff to one file or directory:

`tuicr -p {{path/to/file}}`

- Review a GitHub pull request:

`tuicr pr {{pull_request_number}}`

- Export review comments to standard output:

`tuicr --stdout -w`

- Bypass the local shell wrapper and open the commit selector:

`command tuicr`
