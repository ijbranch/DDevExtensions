"""Export every modified .dfm from git history as old/new file pairs for DfmNoiseMeasure.

Usage:
    python Export-DfmHistory.py <out-folder> <repo> [<repo>...] [--since YYYY-MM-DD]

For each commit that MODIFIED a .dfm ( additions, deletions and renames are not pairs ), the
file at the commit's first parent and at the commit are written byte for byte to
<out-folder>/files/<n>_old.dfm and <n>_new.dfm, and one line is added to <out-folder>/pairs.tsv:
repo, commit, date, path, old file, new file ( paths relative to <out-folder> ).  Then run:

    DfmNoiseMeasure.exe compare <out-folder>/pairs.tsv <out-folder>/detail.csv

Read-only on the repositories: it runs only `git log` and `git cat-file`.
"""

import argparse
import os
import subprocess
import sys


def git(repo, *args):
    """Runs git in a repository and returns its stdout as bytes; raises on failure."""
    return subprocess.run(['git', '-C', repo, '-c', 'core.quotePath=false', *args],
                          check=True, capture_output=True, stdin=subprocess.DEVNULL).stdout


def modified_dfms(repo, since):
    """Yields ( commit, date, path ) for every .dfm a commit modified, oldest first."""
    args = ['log', '--reverse', '--no-renames', '--diff-filter=M', '--name-only', '-z',
            '--format=%x01%H%x09%cs']
    if since:
        args.append('--since=' + since)
    args += ['--', '*.dfm', '*.DFM', '*.Dfm']
    out = git(repo, *args).decode('utf-8', errors='replace')
    for block in out.split('\x01')[1:]:
        header, _, rest = block.partition('\n')
        commit, date = header.strip('\x00\n ').split('\t')
        date = date.strip('\x00\n ')
        for path in rest.split('\x00'):
            path = path.strip('\n')
            if path.lower().endswith('.dfm'):
                yield commit, date, path


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('out')
    parser.add_argument('repos', nargs='+')
    parser.add_argument('--since', default='')
    args = parser.parse_args()

    files_dir = os.path.join(args.out, 'files')
    os.makedirs(files_dir, exist_ok=True)
    index = 0
    with open(os.path.join(args.out, 'pairs.tsv'), 'w', encoding='utf-8', newline='\r\n') as pairs:
        pairs.write('repo\tcommit\tdate\tpath\told\tnew\n')
        for repo in args.repos:
            name = os.path.basename(os.path.normpath(repo))
            count = 0
            for commit, date, path in modified_dfms(repo, args.since):
                try:
                    old = git(repo, 'cat-file', 'blob', commit + '^:' + path)
                    new = git(repo, 'cat-file', 'blob', commit + ':' + path)
                except subprocess.CalledProcessError:
                    continue  # a root commit, or the path is missing in the first parent of a merge
                index += 1
                count += 1
                old_name = 'files/%05d_old.dfm' % index
                new_name = 'files/%05d_new.dfm' % index
                with open(os.path.join(args.out, old_name), 'wb') as f:
                    f.write(old)
                with open(os.path.join(args.out, new_name), 'wb') as f:
                    f.write(new)
                pairs.write('\t'.join([name, commit[:10], date, path, old_name, new_name]) + '\n')
            print('%-32s %5d pairs' % (name, count))
    print('Total %d pairs in %s' % (index, os.path.join(args.out, 'pairs.tsv')))
    return 0


if __name__ == '__main__':
    sys.exit(main())
