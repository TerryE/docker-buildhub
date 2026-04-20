<?php
/**
 * generate-sitemaps.php
 *
 * Generates static XML sitemap files from the ICS core_sitemap table.
 * Designed to be run from cron (CLI only).
 */
     
require_once '/var/www/ipb/conf_global.php';
$base_url    = rtrim($INFO['base_url'], '/') . '/';
$sitemap_dir = '/var/www/sitemap';
$master_file = "$sitemap_dir/sitemap.xml";
$ts_file     = "$sitemap_dir/.last_generated";
$last_time   = file_exists($ts_file) ? (int) @file_get_contents($ts_file) : 0;
$fix_updated = $argc > 1 && $argv[1] == "-F";

// --- Helper function for error exit ----
function abort($message) {
    file_put_contents('php://stderr', $message . PHP_EOL);
    exit(1);
}

// ---- Create/Remove a lockfile in /sitemap/ ----
function lock_sitemaps($sitemap_dir, $lock) {
    global $fp;
    $lock_file = "$sitemap_dir/.generate-sitemaps.lock";
    if ($lock) {
    	// This fails if we don't have wx to the dir or its already locked
        $fp = @fopen($lock_file, 'c');
        if ($fp == false || !flock($fp, LOCK_EX | LOCK_NB)) {
            abort("Can't lock the sitemap folder");
        }
    } else {
        flock($fp, LOCK_UN);
        fclose($fp);
    }
}

// ---- Open the DB, fetch the sitemaps, cleanup and close ----
function get_sitemaps($INFO, $fix_updated, $last_time) {
    $forum_start_ts = 1463788800;
    // Required config keys
    foreach ( ['host', 'user', 'pass', 'database', 'socket'] as $key) {
        if (!isset($INFO) || !is_array($INFO) || empty($INFO['sql_'.$key])) {
            abort("Missing or empty required config key: $key");
        }
    }
    $db = @new mysqli($INFO['sql_host'],$INFO['sql_user'],$INFO['sql_pass'],
                      $INFO['sql_database'], null, $INFO['sql_socket']);
    if ($db->connect_error) {
        abort("Database connection failed: " . $db->connect_error);
    }
    // ICS requires PHP 8.1 so need to limit Mysqli API to 8.1 calls
    $db->set_charset('utf8mb4');
    $get  = $db->prepare("SELECT sitemap, updated, IF(updated > ?, data, NULL) AS data FROM core_sitemap");
    $get->execute([$last_time]);
    $rs   = $get->get_result();
    $sitemaps = [];
    foreach ($rs->fetch_all(MYSQLI_NUM) as list($sitemap, $updated, $data)) {
        if ($fix_updated) {
	    preg_match_all('|<lastmod>(.+?)</lastmod>|', $data, $matches, PREG_PATTERN_ORDER);
            $new_updated = $forum_start_ts;
            foreach ($matches[1] as $dts) {
                $u_dts = date("U",strtotime($dts));
		if ($u_dts > $new_updated) $new_updated = $u_dts;
            }
            $updated = $new_updated;
	}
	$sitemaps[str_replace("sitemap_content_","",$sitemap)] = ['data'=>$data, 'updated'=>$updated];
    }
    $rs->free();
    $db->close();
    return $sitemaps;
}

// ---- Create Master sitemap data ----
function create_master($sitemaps){
    $max_updated = 0;
    $chunk = [];
    $chunk[] = <<<EOD
    <?xml version="1.0" encoding="UTF-8"?>
    <sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    EOD;
    foreach ($sitemaps as $map => $v) {
        $updated = $v['updated'];
        if ($updated > $max_updated) $max_updated = $updated;
        $sitemap_url = "{base_url}sitemap/{$map}.xml";
        $esc_url     = htmlspecialchars($sitemap_url, ENT_XML1, 'UTF-8');
        $lastmod     = htmlspecialchars(date('c', $updated), ENT_XML1, 'UTF-8');
        $chunk[] = <<<EOD
          <sitemap>
            <loc>$esc_url</loc>
            <lastmod>$lastmod</lastmod>
          </sitemap>
        EOD;
    }
    $chunk[] =  <<<EOD
    </sitemapindex>
    EOD;
    $data = implode(PHP_EOL, $chunk);
    return [ 'data'=>$data, 'updated' =>$max_updated ];
}

// ---- main code ----

lock_sitemaps($sitemap_dir, true); // Ensure we are the only instance running

$sitemaps = get_sitemaps($INFO, $fix_updated, $last_time); // will hold all records (for index)
$sitemaps['sitemap'] = create_master($sitemaps);

$status      = true;
$replaced    = [];
foreach( $sitemaps as $map => $v ) { 
    if ($v['data'] == null) continue;

    $data = str_replace('{base_url}', $base_url, $v['data']);
    $updated = $v['updated'];
    // Only replace the XML file is the updated attribute is later
    $last_updated = @filemtime("$sitemap_dir/{$map}.xml");
    if ((!$last_updated) || ($updated > $last_updated)) {
        $temp_file = "$sitemap_dir/{$map}.xml_new";
        if (file_put_contents($temp_file, $data) === false) {
            error_log( "Error: Failed to write $temp_file");
            $status = false;
            break;
        }
        $replaced[] = $map;
    }
}
if (!$status) {
    foreach ($replaced as $tf) {
        @unlink("$sitemap_dir/{$tf}.xml_new");
    }
    abort("Failure during XML creation");
}

// Now move all new sitemap temp files to their final locations  Note rename updates the file DTS,
// so we defer touching the file until after the move 

foreach ($replaced as $map) {

    $v = $sitemaps[$map];
    if ($v['data'] == null) continue;

    $from = "$sitemap_dir/{$map}.xml_new";
    $to   = "$sitemap_dir/{$map}.xml";
    if (! @rename($from, $to)) {
        // If a move fails, we cannot rollback previous replaced, but we can at least abort and log.
        // The next run will fix inconsistencies because the master index hasn't been updated yet.
        error_log("Failed to move {$from} to {$to}");
    }
#   echo "Setting {$to} to ".date('c', $v['updated'])."\n"; 
    if (!touch($to, $v['updated'])) {
        // Not fatal, but log
        error_log("Warning: Could not set mtime on $to");
    }
}

// ------------------------- Clean up -------------------------
lock_sitemaps($sitemap_dir, false);
file_put_contents($ts_file, $sitemaps['sitemap']['updated']);
echo "Sitemap generation completed. Updated ".count($replaced)." of ".count($sitemaps)." sitemaps.\n";
exit(0); 

# vim: autoindent expandtab tabstop=4 shiftwidth=4
