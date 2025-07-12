<?php
echo "Hello from PHP!\n";
echo "Web interface ready.\n";

// Test SQLite
try {
    $db = new PDO('sqlite::memory:');
    echo "SQLite connection: OK\n";
} catch (PDOException $e) {
    echo "SQLite error: " . $e->getMessage() . "\n";
}
?>
