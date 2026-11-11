
CC       = gcc
CXX      = g++

# Compiler settings
CFLAGS   = -Wall -Wextra -std=gnu11 -O2 -pthread -Iinclude
CXXFLAGS = -Wall -Wextra -std=c++14 -O2 -pthread -Iinclude
LDFLAGS  = -pthread

# Directories
SRC_DIR   = src
INC_DIR   = include
TEST_DIR  = tests
BUILD_DIR = build

# Source files (queue.c remains unchanged)
SRC_FILES = copy.c parallel.c dir.c queue.c utils.c log.c

OBJ_FILES = $(patsubst %.c,$(BUILD_DIR)/%.o,$(SRC_FILES))
MAIN_OBJ  = $(BUILD_DIR)/main.o

TARGET  = mycp
TEST_C  = $(TEST_DIR)/test_mycp
TEST_GT = $(TEST_DIR)/gtest_mycp

# Google Test libraries
GTEST_LIBS = $(shell pkg-config --cflags --libs gtest_main 2>/dev/null || echo -lgtest_main -lgtest)

# Static analysis
CPPCHECK = cppcheck

.PHONY: all clean test gtest cppcheck misra analyze valgrind coverage

# --------------------------------------------------
# Main application
# --------------------------------------------------

all: $(TARGET)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c $(INC_DIR)/mycp.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET): $(OBJ_FILES) $(MAIN_OBJ)
	$(CC) $^ $(LDFLAGS) -o $@

$(MAIN_OBJ): $(SRC_DIR)/main.c $(INC_DIR)/mycp.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# --------------------------------------------------
# C Unit Tests
# --------------------------------------------------

$(TEST_C): $(TEST_DIR)/test_mycp.c $(OBJ_FILES) $(INC_DIR)/mycp.h
	$(CC) $(CFLAGS) -o $@ $(TEST_DIR)/test_mycp.c $(OBJ_FILES) $(LDFLAGS)

test: $(TEST_C)
	./$(TEST_C)
	bash $(TEST_DIR)/test_cli.sh

# --------------------------------------------------
# Google Test - C++14
# --------------------------------------------------

$(TEST_GT): $(TEST_DIR)/gtest_mycp.cpp $(OBJ_FILES) $(INC_DIR)/mycp.h
	$(CXX) $(CXXFLAGS) -o $@ $(TEST_DIR)/gtest_mycp.cpp $(OBJ_FILES) $(GTEST_LIBS) $(LDFLAGS)

gtest: $(TEST_GT)
	./$(TEST_GT)

# --------------------------------------------------
# Cppcheck - C and C++ source and test files
# --------------------------------------------------

cppcheck:
	bash $(TEST_DIR)/run_cppcheck.sh cppcheck

# --------------------------------------------------
# MISRA C Analysis
# --------------------------------------------------

misra:
	bash $(TEST_DIR)/run_cppcheck.sh misra

analyze: cppcheck misra

# --------------------------------------------------
# Valgrind
# --------------------------------------------------

valgrind: $(TEST_C)
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
	rm -rf $(BUILD_DIR)
	rm -f $(TARGET) $(TEST_C) $(TEST_GT)
	rm -rf cov
	rm -f *.gcda *.gcno *.gcov
