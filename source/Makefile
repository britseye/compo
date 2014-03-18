DC = dmd
OBJDIR = objdir
DFLAGS = -release -m32 -O -w -odobjdir -I/usr/local/include/d/gtkd-2
LFLAGS = -L-L/usr/lib/i386-linux-gnu -L-L/usr/local/lib -L-L./lib -L-l:libusps4cb.a -L-lgtkd-2 -L-ldl -L-lpthread -L-lm -L-lrt -L-l:librsvg-2.so.2 -L-l:libphobos2.so

COMPILE = $(DC) -c $(DFLAGS)

OBJFILES := $(patsubst %.d,$(OBJDIR)/%.o,$(wildcard *.d))

all: compo

compo: $(OBJFILES)
	$(DC) -ofi386/compo $(OBJFILES) $(LFLAGS)

$(OBJDIR)/%.o: %.d
	$(COMPILE) $<

clean:
	rm $(OBJDIR)/*.o
	rm i386/compo

