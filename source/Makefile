# fp64 - fprintf function for x64
# 24 Jun 2025
# makefile

objs = fp64.o test.o
name = fp64

all: $(name)

$(name): $(objs)
	ld	-o $(name) $(objs)

%.o: %.asm
	as	-o $@ $<

clean:
	rm	-rf $(name) $(objs)

