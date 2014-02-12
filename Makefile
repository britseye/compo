DC = dmd
OBJDIR = objdir
DFLAGS = -release -O -w -odobjdir -I/usr/local/include/d/gtkd-2
LFLAGS = -L-L/usr/lib/i386-linux-gnu -L-L/usr/local/lib -L-L/home/steve/COMPO/lib -L-lusps4cb -L-lgtkd-2 -L-ldl -L-lpthread -L-lm -L-lrt -L-lrsvg -L-l:libphobos2.a

COMPILE = $(DC) -c $(DFLAGS)

OBJFILES := $(patsubst %.d,$(OBJDIR)/%.o,$(wildcard *.d))

all: compo

compo: $(OBJFILES)
	$(DC) -ofi386/compo $(OBJFILES) $(LFLAGS)

$(OBJDIR)/%.o: %.d
	$(COMPILE) $<

clean:
	rm $(OBJDIR)/*.o
	rm compo

