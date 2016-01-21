Tool to investigate what processes in uninterruptible state are doing

    ./dstat.sh 1 1000

Run every second for 1000 times and display the waiting channel of uninterruptible state, and the stack
of the processes in uninterruptible state owned by the current user.

Explanation:

Write system call in synchronous mode on an ext3 file system, waiting for the journaling thread to commit the metadata

    D+       20502 freedge  log_wait_commit   dd if=/dev/zero of=todel count=100 bs=409600 oflag=sync
    Thu Jan 21 11:36:41 MET 2016
    ===== 20502
    [<ffffffffa010f095>] log_wait_commit+0xb5/0x130 [jbd]
    [<ffffffffa012acca>] ext3_sync_file+0xda/0xf0 [ext3]
    [<ffffffff811218cb>] vfs_fsync_range+0xab/0xe0
    [<ffffffff810b6aa6>] generic_file_aio_write+0x76/0xb0
    [<ffffffff810fc963>] do_sync_write+0xe3/0x130
    [<ffffffff810fcfae>] vfs_write+0xce/0x140
    [<ffffffff810fd123>] sys_write+0x53/0xa0

Caught a synchronous write doing IOs:

    D+       30790 freedge  blkdev_issue_flus dd if=/dev/zero of=todel count=1000 bs=4096 conv=notrunc oflag=dsync
    Thu Jan 21 11:42:46 MET 2016
    ===== 30790
    [<ffffffff811ba01c>] blkdev_issue_flush+0xac/0xe0
    [<ffffffffa012acad>] ext3_sync_file+0xbd/0xf0 [ext3]
    [<ffffffff811218cb>] vfs_fsync_range+0xab/0xe0
    [<ffffffff810b6aa6>] generic_file_aio_write+0x76/0xb0
    [<ffffffff810fc963>] do_sync_write+0xe3/0x130
    [<ffffffff810fcfae>] vfs_write+0xce/0x140
    [<ffffffff810fd123>] sys_write+0x53/0xa0

Who knows :)

    D+       10340 freedge  sync_page         dd if=/dev/zero of=todel count=10 bs=4096 conv=notrunc oflag=dsync
    ===== 10340
    [<ffffffff810b4805>] sync_page+0x35/0x60
    [<ffffffff810b4c6c>] wait_on_page_bit+0x6c/0x80
    [<ffffffff810b5c54>] wait_on_page_writeback_range+0xc4/0x140
    [<ffffffff810b5dcf>] filemap_write_and_wait_range+0x6f/0x80
    [<ffffffff811218ab>] vfs_fsync_range+0x8b/0xe0
    [<ffffffff810b6aa6>] generic_file_aio_write+0x76/0xb0
    [<ffffffff810fc963>] do_sync_write+0xe3/0x130
    [<ffffffff810fcfae>] vfs_write+0xce/0x140
    [<ffffffff810fd123>] sys_write+0x53/0xa0

An fdatasync doing its job:

    D+       30819 freedge  blkdev_issue_flus dd if=/dev/zero of=todel count=10 bs=4096 conv=notrunc,fdatasync
    ===== 30819
    [<ffffffff811ba01c>] blkdev_issue_flush+0xac/0xe0
    [<ffffffffa012acad>] ext3_sync_file+0xbd/0xf0 [ext3]
    [<ffffffff811218cb>] vfs_fsync_range+0xab/0xe0
    [<ffffffff811219a6>] do_fsync+0x36/0x60
    [<ffffffff811219de>] sys_fdatasync+0xe/0x20

An fsync caught waiting for the journaling thread to finish:

    D         2598 root     sync_buffer       [kjournald]
    D+        6359 freedge  log_wait_commit   dd if=/dev/zero of=todel count=10 bs=4096 conv=notrunc,fsync
    ===== 6359
    [<ffffffffa010f095>] log_wait_commit+0xb5/0x130 [jbd]
    [<ffffffffa012acca>] ext3_sync_file+0xda/0xf0 [ext3]
    [<ffffffff811218cb>] vfs_fsync_range+0xab/0xe0
    [<ffffffff811219a6>] do_fsync+0x36/0x60
    [<ffffffff811219fb>] sys_fsync+0xb/0x20



