objs = fp86.o test.o
name = fp86

all: $(name)

$(name): $(objs)
	ld	-o $(name) $(objs)

%.o: %.asm
	as	-o $@ $<

clean:
	rm	-rf $(name) $(objs)

