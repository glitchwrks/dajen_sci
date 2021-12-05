RMFLAGS		= -f

ASM		= a85
RM		= rm

all: monitor16 original

monitor16:
	$(ASM) monitor16.asm -o monitor16.hex -l monitor16.prn

original:
	$(ASM) monitor16.orig -o monitor16.orig.hex -l monitor16.orig.prn

clean:
	$(RM) $(RMFLAGS) *.hex *.prn

distclean: clean
