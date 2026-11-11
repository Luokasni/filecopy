
CC       = gcc
CXX      = g++

CFLAGS   = -Wall -Wextra -std=gnu11 -O2 -pthread
CXXFLAGS = -Wall -Wextra -std=c++14 -O2 -pthread
LDFLAGS  = -pthread

INCLUDES = -Iinclude

# Directories
SRC_DIR  = src
INC_DIR  = include
TEST_DIR = tests

# Source object files
LIB_OBJS = copy.o parallel.o dir.o queue.o utils.o log.o
OBJS     = main.o $(LIB_OBJS)

TARGET   = mycp
TEST_C   = $(TEST_DIR)/test_mycp
TEST_GT  = $(TEST_DIR)/gtest_mycp

# Google Test
GTEST_LIBS = $(shell pkg-config --cflags --libs gtest_main 2>/dev/null || echo -lgtest_main -lgtest)

# Cppcheck and MISRA
CPPCHECK = cppcheck
PYTHON   = python3

CPPCHECK_FLAGS = --enable=all \
                 --inconclusive \
                 --force \
                 --inline-suppr \
                 --suppress=missingIncludeSystem \
                 --error-exitcode=1 \
                 $(INCLUDES)

MISRA_ADDON = misra.py
MISRA_RULES = misra_rules.txt

# --------------------------------------------------
# Main application
# --------------------------------------------------

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS) $(LDFLAGS)

%.o: $(SRC_DIR)/%.c $(INC_DIR)/mycp.h
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

# --------------------------------------------------
# C Unit Tests
# --------------------------------------------------

$(TEST_C): $(TEST_DIR)/test_mycp.c $(LIB_OBJS) $(INC_DIR)/mycp.h
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $(TEST_DIR)/test_mycp.c $(LIB_OBJS) $(LDFLAGS)

test: $(TARGET) $(TEST_C)
	./$(TEST_C)
	bash $(TEST_DIR)/test_cli.sh

# --------------------------------------------------
# Google Test - C++14
# --------------------------------------------------

ifneq ($(wildcard /usr/local/include/gtest/gtest.h),)
GTEST_LIBS = -I/usr/local/include -L/usr/local/lib64 -L/usr/local/lib \
             -Wl,-rpath,/usr/local/lib64 -Wl,-rpath,/usr/local/lib \
             -lgtest_main -lgtest
endif

ifdef GTEST_SRC
GTEST_LIBS = -I$(GTEST_SRC)/googletest/include \
             -I$(GTEST_SRC)/googletest \
             $(GTEST_SRC)/googletest/src/gtest-all.cc \
             $(GTEST_SRC)/googletest/src/gtest_main.cc
endif

$(TEST_GT): $(TEST_DIR)/gtest_mycp.cpp $(LIB_OBJS) $(INC_DIR)/mycp.h
	$(CXX) $(CXXFLAGS) $(INCLUDES) -o $@ $(TEST_DIR)/gtest_mycp.cpp $(LIB_OBJS) $(GTEST_LIBS) $(LDFLAGS)

gtest: $(TEST_GT)
	./$(TEST_GT)

# --------------------------------------------------
# Cppcheck - Static Analysis
# --------------------------------------------------

cppcheck:
	$(CPPCHECK) $(CPPCHECK_FLAGS) $(SRC_DIR)/ $(TEST_DIR)/

# --------------------------------------------------
# MISRA C Compliance
# --------------------------------------------------

misra:
	$(CPPCHECK) --enable=all --force \
		--addon=$(MISRA_ADDON) \
		--inline-suppr \
		--suppress=missingIncludeSystem \
		$(INCLUDES) $(SRC_DIR)/

# --------------------------------------------------
# Valgrind - Memory Testing
# --------------------------------------------------

valgrind: $(TARGET) $(TEST_C)
	bash $(TEST_DIR)/run_valgrind.sh

# --------------------------------------------------
# Code Coverage
# --------------------------------------------------

coverage:
	bash $(TEST_DIR)/run_coverage.sh

# --------------------------------------------------
# Clean
# --------------------------------------------------

clean:
	rm -f $(OBJS) $(TARGET) $(TEST_C) $(TEST_GT)
	rm -rf cov
	rm -f *.gcda *.gcno *.gcov

.PHONY: all test gtest cppcheck misra valgrind coverage clean
