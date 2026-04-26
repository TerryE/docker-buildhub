<?php
declare(strict_types=1);

const SITE      = 'https://forum.buildhub.org.uk';
const MAX_URLS  = 50000;
const MAX_BYTES = 50_000_000;

define('OUTPUT_FILE', getenv('BUILDHUB_SITEMAP_TXT') ?: '/var/www/ipb/sitemap.txt');

function load_db_config(): array {
    $host = getenv('BUILDHUB_DB_HOST') ?: null;
    $name = getenv('BUILDHUB_DB_NAME') ?: null;
    $user = getenv('BUILDHUB_DB_USER') ?: null;
    $pass = getenv('BUILDHUB_DB_PASS');

    if ($host && $name && $user) {
        return ['host' => $host, 'name' => $name, 'user' => $user, 'pass' => (string)$pass];
    }

    $confPath = getenv('BUILDHUB_CONF_GLOBAL') ?: null;
    if ($confPath && is_readable($confPath)) {
        $info = (function (string $p): array {
            $INFO = [];
            require $p;
            return $INFO;
        })($confPath);
        if (isset($info['sql_host'], $info['sql_database'], $info['sql_user'])) {
            return [
                'host' => $info['sql_host'],
                'name' => $info['sql_database'],
                'user' => $info['sql_user'],
                'pass' => (string)($info['sql_pass'] ?? ''),
            ];
        }
        fwrite(STDERR, "WARNING: BUILDHUB_CONF_GLOBAL=$confPath did not yield a usable \$INFO array; falling back to defaults.\n");
    }

    return ['host' => '127.0.0.1', 'name' => 'buildhub', 'user' => 'root', 'pass' => ''];
}

function connect(array $cfg): PDO {
    $dsn = "mysql:host={$cfg['host']};dbname={$cfg['name']};charset=utf8mb4";
    $bufferedAttr = defined('Pdo\\Mysql::ATTR_USE_BUFFERED_QUERY')
        ? constant('Pdo\\Mysql::ATTR_USE_BUFFERED_QUERY')
        : PDO::MYSQL_ATTR_USE_BUFFERED_QUERY;
    return new PDO($dsn, $cfg['user'], $cfg['pass'], [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        $bufferedAttr                => false,
    ]);
}

function resolve_guest_group_id(PDO $db): int {
    $stmt = $db->query(
        "SELECT word_key FROM core_sys_lang_words
         WHERE word_default = 'Guests' AND word_key LIKE 'core_group_%'
         LIMIT 1"
    );
    $row = $stmt->fetch();
    $stmt->closeCursor();
    if ($row && preg_match('/^core_group_(\d+)$/', $row['word_key'], $m)) {
        return (int)$m[1];
    }
    return 2;
}

function build_topic_url(int $tid, string $slug): string {
    $slug = $slug !== '' ? $slug : (string)$tid;
    return SITE . '/topic/' . $tid . '-' . rawurlencode($slug) . '/';
}

function main(): int {
    $start = microtime(true);
    $cfg = load_db_config();

    try {
        $db = connect($cfg);
    } catch (PDOException $e) {
        fwrite(STDERR, "DB connection failed: {$e->getMessage()}\n");
        return 1;
    }

    $guestGid = resolve_guest_group_id($db);

    $sql = "
        SELECT t.tid, t.title_seo
        FROM forums_topics t
        INNER JOIN forums_forums f ON f.id = t.forum_id
        INNER JOIN core_permission_index p
            ON p.app = 'forums' AND p.perm_type = 'forum' AND p.perm_type_id = f.id
        WHERE t.approved = 1
          AND t.topic_archive_status = 0
          AND t.state IN ('open', 'closed')
          AND f.redirect_url IS NULL
          AND f.sub_can_post = 1
          AND (f.club_id IS NULL OR f.club_id = 0)
          AND (p.perm_view = '*' OR FIND_IN_SET(:gid, p.perm_view) > 0)
        ORDER BY t.last_post DESC
        LIMIT " . (MAX_URLS - 1);

    $stmt = $db->prepare($sql);
    $stmt->bindValue(':gid', (string)$guestGid, PDO::PARAM_STR);
    $stmt->execute();

    $tmp = OUTPUT_FILE . '.tmp';
    $fh = fopen($tmp, 'wb');
    if ($fh === false) {
        fwrite(STDERR, "Could not open $tmp for writing\n");
        return 1;
    }

    $homepageLine = SITE . "\n";
    fwrite($fh, $homepageLine);
    $urls  = 1;
    $bytes = strlen($homepageLine);
    $truncatedBy = null;

    while ($row = $stmt->fetch()) {
        $line = build_topic_url((int)$row['tid'], (string)$row['title_seo']) . "\n";
        $lineBytes = strlen($line);

        if ($urls >= MAX_URLS)               { $truncatedBy = 'URL count (50,000)'; break; }
        if ($bytes + $lineBytes > MAX_BYTES) { $truncatedBy = 'byte size (50 MB)';    break; }

        fwrite($fh, $line);
        $urls++;
        $bytes += $lineBytes;
    }
    $stmt->closeCursor();
    fclose($fh);

    if (!rename($tmp, OUTPUT_FILE)) {
        fwrite(STDERR, "Could not rename $tmp to " . OUTPUT_FILE . "\n");
        @unlink($tmp);
        return 1;
    }

    $elapsed = number_format(microtime(true) - $start, 2);
    $mb      = number_format($bytes / 1_048_576, 2);
    printf(
        "Wrote %s URLs (%s bytes, %s MB) to %s in %ss (guest group id=%d)\n",
        number_format($urls), number_format($bytes), $mb, OUTPUT_FILE, $elapsed, $guestGid
    );
    if ($truncatedBy !== null) {
        printf("NOTE: truncated by %s — older topics omitted from this run.\n", $truncatedBy);
    }
    if ($urls < 10) {
        fwrite(STDERR, "WARNING: only $urls URLs written — check guest group id ($guestGid) and forum permissions.\n");
    }

    return 0;
}

exit(main());
