define ruby_stack_trace
 # Version 0.0.2 - 2012-07-25
 # First, move_down_to_the_frame_of_thread_start_func_2
 set $a = vm_exec_core
 set $b = vm_exec
 set $f = 0
 set $found = 0
 while $f < 50
  frame $f
  if $a <= $pc && $pc <= $b
   set $found = 1
   loop_break
  end
  set $f = $f + 1
 end
 printf "\n"
 thread
 if $found
  # Second, dump the stack trace using an argument 'th='
  set $VM_FRAME_MAGIC_METHOD = 0x11
  set $VM_FRAME_MAGIC_BLOCK =  0x21
  set $VM_FRAME_MAGIC_CLASS =  0x31
  set $VM_FRAME_MAGIC_TOP =    0x41
  set $VM_FRAME_MAGIC_FINISH = 0x51
  set $VM_FRAME_MAGIC_CFUNC =  0x61
  set $VM_FRAME_MAGIC_PROC =   0x71
  set $VM_FRAME_MAGIC_IFUNC =  0x81
  set $VM_FRAME_MAGIC_EVAL =   0x91
  set $VM_FRAME_MAGIC_LAMBDA = 0xa1
  set $VM_FRAME_MAGIC_MASK_BITS = 8
  set $VM_FRAME_MAGIC_MASK = (~(~0 << $VM_FRAME_MAGIC_MASK_BITS))
  set $RUBY_T_NODE = 0x1c
  set $RUBY_T_MASK = 0x1f
  set $T_NODE = $RUBY_T_NODE
  set $T_MASK = $RUBY_T_MASK
  set $FL_USHIFT = 12
  set $FL_USER1 = ((1)<<($FL_USHIFT+1))
  set $RSTRING_NOEMBED = $FL_USER1
  set $p = th->cfp
  while $p < th->stack + th->stack_size
   set $VM_FRAME_TYPE = (($p)->flag & $VM_FRAME_MAGIC_MASK)
   printf "#%-2d ", $p - th->cfp
   set $nopos = 0
   set $t = $VM_FRAME_TYPE
   if $t == $VM_FRAME_MAGIC_METHOD
    printf "METHOD "
   end
   if $t == $VM_FRAME_MAGIC_BLOCK
    printf "BLOCK  "
   end
   if $t == $VM_FRAME_MAGIC_CLASS
    printf "CLASS  "
   end
   if $t == $VM_FRAME_MAGIC_TOP
    printf "TOP    "
   end
   if $t == $VM_FRAME_MAGIC_FINISH
    printf "FINISH "
    set $nopos = 1
   end
   if $t == $VM_FRAME_MAGIC_CFUNC
    printf "CFUNC  "
   end
   if $t == $VM_FRAME_MAGIC_PROC
    printf "PROC   "
   end
   if $t == $VM_FRAME_MAGIC_IFUNC
    printf "IFUNC   "
   end
   if $t == $VM_FRAME_MAGIC_EVAL
    printf "EVAL    "
   end
   if $t == $VM_FRAME_MAGIC_LAMBDA
    printf "LAMBDA  "
   end
   if $t == 0
    printf "------- "
   end
   if ! $nopos
    if $p->iseq
     if (((struct RBasic*)($p->iseq))->flags & $T_MASK) == $T_NODE
      printf "<ifunc>"
     else
      if ((struct RBasic*)($p->iseq->filename))->flags & $RSTRING_NOEMBED
       printf "%s:", (((struct RString*)($p->iseq->filename))->as).heap.ptr
      else
       printf "%s:", (((struct RString*)($p->iseq->filename))->as).ary
      end
      printf "%d %s", rb_vm_get_sourceline($p), rb_class2name($p->iseq->klass)
     end
    else
     if $p->method_id
      printf ":%s", rb_id2name($p->method_id)
     end
    end
   end
   printf "\n"
   set $p = $p + 1
  end
 else
  printf "This frame seems not to contain a ruby stack.\n"
 end
end
 
document ruby_stack_trace
 Prints backtrace of all stack frames in the level of Ruby script.
 Notes: This command is intended to use with Ruby 1.9.1.
end
