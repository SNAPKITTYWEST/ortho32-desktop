CC ?= gcc
CFLAGS ?= -fPIC -O2 -Wall -Wextra -std=c11
LDFLAGS_SHARED ?= -shared

UNAME_S := $(shell uname -s)
TARGET := ortho_sim.so
LDFLAGS := $(LDFLAGS_SHARED)

ifeq ($(OS),Windows_NT)
  TARGET := ortho_sim.dll
  LDFLAGS := -shared
  CFLAGS += -DWIN32
endif

ifneq (,$(findstring Darwin,$(UNAME_S)))
  TARGET := ortho_sim.dylib
  LDFLAGS := -dynamiclib
endif

SRC := ortho_sim.c
OBJ := ortho_sim.o
HDR := ortho_sim.h

# Optional: USE_CBLAS=1 make
ifeq ($(USE_CBLAS),1)
  CFLAGS += -DUSE_CBLAS
  LDLIBS += -lopenblas -lcblas
endif

all: $(TARGET) test_sim

$(TARGET): $(OBJ)
	$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)

$(OBJ): $(SRC) $(HDR)
	$(CC) $(CFLAGS) -c $< -o $@

test_sim: test_sim.c $(TARGET)
	$(CC) $(CFLAGS) -o $@ test_sim.c -L. -l:./$(TARGET) 2>/dev/null || $(CC) $(CFLAGS) -o $@ test_sim.c ortho_sim.c -lc

# Fallback static link test without shared lib dependency
test_sim_static: test_sim.c ortho_sim.c
	$(CC) $(CFLAGS) -o test_sim test_sim.c ortho_sim.c

test: test_sim_static
	./test_sim
	@echo "test passed: cycles==768 and hash is 64-char hex"

clean:
	rm -f $(OBJ) $(TARGET) test_sim *.o *.so *.dll *.dylib

.PHONY: all test clean
