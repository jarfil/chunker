# chunker.sh
Split and compress large files with multi-threading in parallel

## why chunker

* uses multi-threading
* can output a Makefile for manual editing
* allows to stop and resume a job
* doesn't require parallel(1)
	* `parallel: Warning: --blocksize >= 64K causes problems on Cygwin.`

### replaces

* split
  * `cat "$FILENAME" | split -d -a3 --bytes="$CHUNKSIZE" --filter='gzip > "$FILENAME".gz' - "$FILENAME."`

### can be replaced with

* GNU parallel
  * `parallel --pipepart -a "$FILENAME" --block "$CHUNKSIZE" 'gzip > $(({#}-1)).gz'`
  * `parallel --pipepart -a "$FILENAME" --block "$CHUNKSIZE" '[[ $(({#}-1)) -ge "$CHUNKSTART" ]] && [[ $(({#}-1)) -le "$CHUNKEND" ]] && gzip > $(({#}-1)).gz'`

# TODO

```
echo "  --compress=none  don't compress"
compress
gzip, 7z, bzip2

single threaded
- specify number of threads
- make load limit --load-average

full support for dd/split unit suffixes for chunk_size

alternative: add makefile output with dd to split
```
