Tool to investigate what processes in uninterruptible state are doing

    ./dstat.sh 1 1000

Run every second for 1000 times and display the waiting channel of uninterruptible state, and the stack
of the processes in uninterruptible state owned by the current user.

Explanation:
------------

Following traces use SLES11 SP3 and SP4 with default file system (ext3 with data=ordered and barrier enabled).

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

Caught a synchronous write doing IOs (waiting for the ext3 barrier to complete)

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

A synchronous write waiting for its pages to be written

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


An *asynchronous* write blocked for some reason? (stable writeback pages?) Under 3.0.101-63-default. This one was run as root and dumped the journaling thread stack as well.

    D          337 root     get_request_wait  [kjournald]
    D+        5074 root     sleep_on_buffer   dd if=/dev/zero of=zer count=10 bs=4096 conv=notrunc,fdatasync
    Sat Jan 23 09:51:29 CET 2016
    ===== 337
    [<ffffffff8122c9a9>] get_request_wait+0x119/0x1c0
    [<ffffffff8122cbd6>] __make_request+0x186/0x420
    [<ffffffff8122b2cb>] generic_make_request+0x45b/0x560
    [<ffffffff8122b428>] submit_bio+0x58/0xf0
    [<ffffffff8118b51f>] _submit_bh+0x11f/0x180
    [<ffffffffa018171e>] journal_submit_data_buffers+0x39e/0x3c0 [jbd]
    [<ffffffffa0181a45>] journal_commit_transaction+0x305/0xe20 [jbd]
    [<ffffffffa018632b>] kjournald+0xdb/0x230 [jbd]
    [<ffffffff81084496>] kthread+0x96/0xa0
    [<ffffffff81470564>] kernel_thread_helper+0x4/0x10
    ===== 5074
    [<ffffffff8118c959>] sleep_on_buffer+0x9/0x10
    [<ffffffff8118d2d8>] __sync_dirty_buffer+0xa8/0xd0
    [<ffffffffa018102b>] journal_dirty_data+0x1db/0x230 [jbd]
    [<ffffffffa01a2d4d>] ext3_journal_dirty_data+0x1d/0x50 [ext3]
    [<ffffffffa01a17db>] walk_page_buffers+0x4b/0xb0 [ext3]
    [<ffffffffa01a5d53>] ext3_ordered_write_end+0x73/0x140 [ext3]
    [<ffffffff810fa6c2>] generic_perform_write+0x122/0x1c0
    [<ffffffff810fa7c1>] generic_file_buffered_write+0x61/0xa0
    [<ffffffff810fd12f>] __generic_file_aio_write+0x20f/0x320
    [<ffffffff810fd28c>] generic_file_aio_write+0x4c/0xb0
    [<ffffffff8115dd17>] do_sync_write+0xd7/0x120
    [<ffffffff8115e35e>] vfs_write+0xce/0x140
    [<ffffffff8115e4d3>] sys_write+0x53/0xa0


Heavy writer getting throttled when hitting the dirty memory limits:

    D          315 root     sleep_on_buffer   [kjournald]
    D          321 root     get_request_wait  [flush-8:0]
    D+        6229 root     -                 dd if=/dev/zero of=todel count=1000 bs=409600
    Sat Jan 23 17:10:59 CET 2016
    ===== 315
    [<ffffffff8118c959>] sleep_on_buffer+0x9/0x10
    [<ffffffffa0181a8e>] journal_commit_transaction+0x34e/0xe20 [jbd]
    [<ffffffffa018632b>] kjournald+0xdb/0x230 [jbd]
    ===== 321
    [<ffffffff8122c9a9>] get_request_wait+0x119/0x1c0
    [<ffffffff8122cbd6>] __make_request+0x186/0x420
    [<ffffffff8122b2cb>] generic_make_request+0x45b/0x560
    [<ffffffff8122b428>] submit_bio+0x58/0xf0
    [<ffffffff8118b51f>] _submit_bh+0x11f/0x180
    [<ffffffff8118d930>] __block_write_full_page+0x1d0/0x320
    [<ffffffff8110523a>] __writepage+0xa/0x40
    [<ffffffff811059a0>] write_cache_pages+0x210/0x460
    [<ffffffff81105c38>] generic_writepages+0x48/0x70
    [<ffffffff81183b31>] writeback_single_inode+0x171/0x360
    [<ffffffff8118443e>] writeback_sb_inodes+0xee/0x1d0
    [<ffffffff81184ca3>] writeback_inodes_wb+0xd3/0x160
    [<ffffffff8118514b>] wb_writeback+0x41b/0x470
    [<ffffffff8118531a>] wb_do_writeback+0x17a/0x250
    [<ffffffff811854d4>] bdi_writeback_thread+0xe4/0x240
    ===== 6229
    [<ffffffff81106520>] balance_dirty_pages+0x310/0x580
    [<ffffffff810fa6f3>] generic_perform_write+0x153/0x1c0
    [<ffffffff810fa7c1>] generic_file_buffered_write+0x61/0xa0
    [<ffffffff810fd12f>] __generic_file_aio_write+0x20f/0x320
    [<ffffffff810fd28c>] generic_file_aio_write+0x4c/0xb0
    [<ffffffff8115dd17>] do_sync_write+0xd7/0x120
    [<ffffffff8115e35e>] vfs_write+0xce/0x140
    [<ffffffff8115e4d3>] sys_write+0x53/0xa0

Caveats:
--------

This is a shell script. It itself spawn processes and consume a bit of memory.

This is useful to investigate latency with ext3, but it will have some hard time
with a system heavilly swapping for example. In that case you might use some
other tool, such as:

    echo t > /proc/sysrq-trigger



