# CRT Filter Native Library Makefile

CC = clang
CFLAGS = -fobjc-arc -fmodules -Wall -Wextra -O2
LDFLAGS = -dynamiclib -framework Cocoa -framework Metal -framework QuartzCore \
          -framework CoreMedia -framework IOSurface -framework ScreenCaptureKit

SRCDIR = src
INCDIR = include
BUILDDIR = build
TARGET = libcrt-native.dylib

SOURCES = $(SRCDIR)/CRTNative.m \
          $(SRCDIR)/OverlayWindow.m \
          $(SRCDIR)/ScreenCapture.m \
          $(SRCDIR)/MetalRenderer.m

OBJECTS = $(patsubst $(SRCDIR)/%.m,$(BUILDDIR)/%.o,$(SOURCES))

.PHONY: all clean install

all: $(BUILDDIR) $(TARGET)

$(BUILDDIR):
	mkdir -p $(BUILDDIR)

$(TARGET): $(OBJECTS)
	$(CC) $(LDFLAGS) -o $@ $(OBJECTS)
	@echo "Built $(TARGET)"

$(BUILDDIR)/%.o: $(SRCDIR)/%.m
	$(CC) $(CFLAGS) -I$(INCDIR) -c $< -o $@

clean:
	rm -rf $(BUILDDIR) $(TARGET)

install: $(TARGET)
	cp $(TARGET) ../
	@echo "Installed $(TARGET) to project root"

# Debug build
debug: CFLAGS += -g -DDEBUG
debug: clean all

# Show help
help:
	@echo "CRT Filter Native Library Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all     - Build the dynamic library (default)"
	@echo "  clean   - Remove build artifacts"
	@echo "  install - Copy library to project root"
	@echo "  debug   - Build with debug symbols"
	@echo "  help    - Show this message"
