Tool to investigate what processes in uninterruptible state are doing

    ./dstat.sh 1 1000

Run every second for 1000 times and display the waiting channel of uninterruptible state, and the stack
of the processes in uninterruptible state owned by the current user.


	./chantime.sh dd if=/dev/zero of=zer count=10 bs=4096 conv=notrunc,fdatasync

Sample a command and give timing information per waiting channel.

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

An fdatasync writing its pages:

    D+       18212 root     sleep_on_page     dd if=/dev/zero of=zer count=1 bs=40960 conv=notrunc,fdatasync
    ===== 18212
    [<ffffffff810fb449>] sleep_on_page+0x9/0x10
    [<ffffffff810fbbbc>] wait_on_page_bit+0x6c/0x80
    [<ffffffff810fcbfb>] filemap_fdatawait_range+0xdb/0x150
    [<ffffffff810fcd67>] filemap_write_and_wait_range+0x67/0x70
    [<ffffffffa01a0577>] ext3_sync_file+0x77/0x190 [ext3]
    [<ffffffff811895d2>] do_fsync+0x32/0x60
    [<ffffffff8118960e>] sys_fdatasync+0xe/0x20
    [<ffffffff8146f3f2>] system_call_fastpath+0x16/0x1b


An fdatasync caught in a barrier

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

Reading a file:

    DN+     966292 devr     sleep_on_page_kil cat ../../D
    Tue Sep 20 17:53:18 GMT 2016
    ===== 966333
    [<ffffffff810fba19>] sleep_on_page_killable+0x9/0x40
    [<ffffffff810fbae6>] __lock_page_killable+0x96/0xd0
    [<ffffffff810fcd27>] do_generic_file_read+0x227/0x490
    [<ffffffff810fd9bc>] generic_file_aio_read+0xfc/0x260
    [<ffffffff8115f417>] do_sync_read+0xd7/0x120
    [<ffffffff8115fbc7>] vfs_read+0xc7/0x130
    [<ffffffff8115fd33>] sys_read+0x53/0xa0


A vxfs filesystem stuck in a rename:

    Dl        2907 devr     sleep_on_buffer   /a
    D        33223 root     sleep_on_buffer   [kjournald]
    D        33237 root     get_request_wait  [kjournald]
    D<s      69190 root     sleep_on_buffer   /o
    D       243335 root     get_request_wait  [flush-199:23001]
    Dl      496247 devr     sleep_on_buffer   /a
    D       608715 devr     log_wait_commit   s
    DN+     608852 devm     get_request_wait  mv b a
    DN      608878 l        sleep_on_page     s
    Tue Sep 20 17:13:32 GMT 2016
    ===== 608852
    [<ffffffff8122e2e9>] get_request_wait+0x119/0x1c0
    [<ffffffff8122e516>] __make_request+0x186/0x420
    [<ffffffff8122cbfb>] generic_make_request+0x45b/0x560
    [<ffffffff8122cd74>] submit_bio+0x74/0x100
    [<ffffffffa07717db>] vx_dev_strategy+0x35b/0x6f0 [vxfs]
    [<ffffffffa06e12cd>] vx_logbuf_write+0x18d/0x1c0 [vxfs]
    [<ffffffffa06e148a>] vx_logbuf_io+0x18a/0x290 [vxfs]
    [<ffffffffa06e233a>] vx_logflush+0xea/0x140 [vxfs]
    [<ffffffffa0775050>] vx_tranidflush+0x120/0x220 [vxfs]
    [<ffffffffa078ab4b>] vx_int_rename+0x19fb/0x2f90 [vxfs]
    [<ffffffffa078c6e4>] vx_do_rename+0x604/0x8b0 [vxfs]
    [<ffffffffa078cd53>] vx_rename1+0x3c3/0x680 [vxfs]
    [<ffffffffa068de66>] vx_rename+0x3c6/0x580 [vxfs]
    [<ffffffff8116b18d>] vfs_rename_other+0xcd/0x120
    [<ffffffff8116c328>] vfs_rename+0x118/0x200
    [<ffffffff8116edb4>] sys_renameat+0x2c4/0x2e0
    [<ffffffffa09bada7>] __sys_rename+0x157/0x300 [secfs2]

A synchronous write on a vxfs filesystem:

    DN+     585323 devm     vx_bc_biowait     dd if=/dev/zero of=out3 bs=4096 count=1000000 oflag=sync
    Tue Sep 20 17:43:02 GMT 2016
    ===== 585323
    [<ffffffffa070eb20>] vx_bc_biowait+0x10/0x30 [vxfs]
    [<ffffffffa059a829>] vx_biowait+0x9/0x30 [vxfs]
    [<ffffffffa06e1284>] vx_logbuf_write+0x144/0x1c0 [vxfs]
    [<ffffffffa06e148a>] vx_logbuf_io+0x18a/0x290 [vxfs]
    [<ffffffffa06e233a>] vx_logflush+0xea/0x140 [vxfs]
    [<ffffffffa0775050>] vx_tranidflush+0x120/0x220 [vxfs]
    [<ffffffffa07a0a4f>] vx_write_common_fast+0x17f/0x200 [vxfs]
    [<ffffffffa07a0f4c>] vx_write_common+0x47c/0x860 [vxfs]
    [<ffffffffa0720ead>] vx_write+0x24d/0x370 [vxfs]
    [<ffffffff8115f93e>] vfs_write+0xce/0x140
    [<ffffffff8115fab3>] sys_write+0x53/0xa0

A find blocked when reading directory entries on a vxfs filesystem:

    DN+     690600 devm     vx_bc_biowait     find ../..
    Tue Sep 20 17:47:03 GMT 2016
    ===== 690600
    [<ffffffffa070eb20>] vx_bc_biowait+0x10/0x30 [vxfs]
    [<ffffffffa059af27>] vx_bread_bp+0xc7/0x250 [vxfs]
    [<ffffffffa059b91d>] vx_getblk_cmn+0x17d/0x1d0 [vxfs]
    [<ffffffffa059b991>] vx_getblk+0x21/0x30 [vxfs]
    [<ffffffffa0630171>] vx_dirbread+0x261/0x440 [vxfs]
    [<ffffffffa07296a1>] vx_readdir_int+0xcf1/0x12b0 [vxfs]
    [<ffffffffa072af7a>] vx_readdir+0x41a/0x880 [vxfs]
    [<ffffffff81171b92>] vfs_readdir+0xc2/0xe0
    [<ffffffff81171c34>] sys_getdents64+0x84/0xe0
    ...
    DN+     690600 devm     vx_bc_biowait     find ../..
    Tue Sep 20 17:48:52 GMT 2016
    ===== 690600
    [<ffffffffa070eb20>] vx_bc_biowait+0x10/0x30 [vxfs]
    [<ffff8817ea3a0bc0>] 0xffff8817ea3a0bc0
    [<ffffffffa07141fb>] vx_daccess+0x7b/0x2e0 [vxfs]
    [<ffffffffa059b991>] vx_getblk+0x21/0x30 [vxfs]
    [<ffffffffa0630171>] vx_dirbread+0x261/0x440 [vxfs]
    [<ffffffffa07296a1>] vx_readdir_int+0xcf1/0x12b0 [vxfs]
    [<ffffffff81171830>] filldir64+0x0/0xe0
    [<ffffffffa072af7a>] vx_readdir+0x41a/0x880 [vxfs]
    [<ffffffff81171830>] filldir64+0x0/0xe0
    [<ffffffff81171830>] filldir64+0x0/0xe0
    [<ffffffff81171b92>] vfs_readdir+0xc2/0xe0
    [<ffffffff81171c34>] sys_getdents64+0x84/0xe0

Reading a file on a vxfs filesystem:

    DN+      17882 devm     lock_page         cat ./G
    Tue Sep 20 17:56:43 GMT 2016
    ===== 17882
    [<ffffffff810fbbb3>] __lock_page+0x93/0xc0
    [<ffffffffa076347d>] vx_segmap_getmap+0x5bd/0x870 [vxfs]
    [<ffffffffa073d3fb>] vx_cache_read+0x18b/0x640 [vxfs]
    [<ffffffffa073e201>] vx_read1+0x5d1/0x9f0 [vxfs]
    [<ffffffffa071f3b9>] vx_vop_read+0xc9/0x120 [vxfs]
    [<ffffffffa071fc27>] vx_read+0x217/0x650 [vxfs]
    [<ffffffff8115fbc7>] vfs_read+0xc7/0x130
    [<ffffffff8115fd33>] sys_read+0x53/0xa0

Caveats:
--------

This is a shell script. It itself spawn processes and consume a bit of memory.

This is useful to investigate latency with ext3, but it will have some hard time
with a system heavilly swapping for example. In that case you might use some
other tool, such as:

    echo t > /proc/sysrq-trigger



