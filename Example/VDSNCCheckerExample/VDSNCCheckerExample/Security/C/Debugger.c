#include "Debugger.h"

/// Ensures no other debugger can attach to the calling process; if a debugger attempts to attach, the process will terminate
void disable_gdb() {
#if DEBUG
    return;
#endif
__asm (
           "mov x0, #31\n" // to define PT_DENY_ATTACH (31) to x0
           "mov x1, #0\n"
           "mov x2, #0\n"
           "mov x3, #0\n" // this is actually ptrace_ptr(PT_DENY_ATTACH, 0, 0, 0) in the  instruction set
           "mov x16, #26\n"  // set the intra-procedural to syscall #26 to invoke ‘ptrace’
           "svc #0x80\n"    // SVC generate supervisor call. Supervisor calls are normally used to request privileged operations or access to system resources from an operating system
           );
}

/// Returns true if process is being debugged
bool isBeingDebugged_sysctl(void) {
    
    // detecting if a debugger is attached by using sysctl
    // according to apple documentation, it allows processes to set system information (if having the appropriate privileges) or simply retrieve system information (such as whether or not the process is being debugged)
    
    size_t size = sizeof(struct kinfo_proc);
    struct kinfo_proc info;
    int ret, name[4];
    
    // initialise the flags so that if (unlikely) sysctl fails we still get a predictable result
    info.kp_proc.p_flag = 0;
     
    // initialise name with tells sysctl we are looking for info on the process id
    name[0] = CTL_KERN;
    name[1] = KERN_PROC;
    name[2] = KERN_PROC_PID;
    name[3] = getpid();
    
    if ((ret = (sysctl(name, 4, &info, &size, NULL, 0)))) {
        return false; /* sysctl() failed for some reason */
    }
    
    // we are being debugged if the Ptraced flag is set
    return ((info.kp_proc.p_flag & P_TRACED) != 0);
}
