# Linux Foundations

> This lab is Module 1 of the **[Linux for DevOps Engineers](https://devoriales.com/quiz/25/linux-for-devops-engineers)** course on [devoriales.com](https://devoriales.com), which is free. The lab is self contained, so you can work through it on its own. The written lessons behind it go further: the kernel and user space split, system calls, and the filesystem in depth.

A web shop is behaving strangely. Checkout is failing for some customers, and the on-call engineer has handed you a copy of yesterday's access log with a note that says "something looks off, can you look?"

You have a terminal and nothing else. No dashboard, no log aggregator, no APM. This is the situation Linux tooling was designed for, and by the end of this lab you will have found both the broken endpoint and an intruder that nobody had noticed.

Getting there means understanding three things first:

- **Where things live.** The filesystem has a standard layout, and knowing it means you can work on a machine you have never seen before.
- **What a file actually is.** A file name and a file are different things, and the difference explains a whole category of production incidents.
- **How small tools combine.** `grep`, `awk`, `sort`, and `uniq` each do one job. Piped together they answer questions that would otherwise need a purpose built application.

## Your environment

You have a root shell on an Ubuntu virtual machine. It is yours for this session and is destroyed when you leave, so nothing here can be damaged permanently. Break things freely.

The evidence has already been placed at `/root/course-data/`:

- `access.log` is 45 requests from the web server, in nginx combined format
- `app.conf` is a small configuration file used when you practise reading metadata

Four steps, roughly thirty minutes. Each one ends with a **Check** button that confirms your work before you move on.

Let's get started.
