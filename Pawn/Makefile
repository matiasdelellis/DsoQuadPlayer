PAWNPATH   = /home/matias/Proyectos/DSO/QuadPawn/

SRCS = $(wildcard *.pawn)
OBJS = $(SRCS:.pawn=.amx)

all: $(OBJS)

clean:
	rm -rf $(OBJS)

%.amx: %.pawn $(PAWNPATH)Compiler/include/*.inc
	$(PAWNPATH)/Compiler/bin/pawncc -d2 -v2 -V1 $<

