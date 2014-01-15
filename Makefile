DC = dmd
OBJDIR = objdir
DFLAGS = -gc -d -odobjdir -I/usr/local/include/d/gtkd-2
LFLAGS = -L-L/usr/lib/i386-linux-gnu -L-L/usr/local/lib -L-L/home/steve/COMPO -L-lusps4cb -L-lgtkd-2 -L-lphobos2 -L-ldl -L-lrt -L-lrsvg

COMPILE = $(DC) -c $(DFLAGS)

OBJFILES := $(patsubst %.d,$(OBJDIR)/%.o,$(wildcard *.d))

all: compo

compo: $(OBJFILES)
	$(DC) -ofcompo $(OBJFILES) $(LFLAGS)

$(OBJDIR)/%.o: %.d
	$(COMPILE) $<

clean:
	rm $(OBJDIR)/*.o
	rm compo

