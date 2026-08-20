#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''
Description:  Selects the default TMDB poster, art and logo for items in a Plex library
              if none is selected or the current one is from Gracenote.
              The selected poster is the primary TMDB poster in the item's original language.
              The selected art is the primary TMDB backdrop.
              The selected logo is the primary TMDB logo in English for English media,
              otherwise in French with a fallback to the original language.
              Can also override the metadata language for non-English media and set
              the sort title without the leading article for French metadata.
Author:       /u/SwiftPanda16 (original), shellt0pia (modifications)
Requires:     plexapi, requests
Environment:  PLEX_URL, PLEX_TOKEN
              TMDB API key read from the file at TMDB_API_KEY_FILE if set,
              otherwise from the TMDB_API_KEY environment variable
Usage:
    * Change the posters for an entire library:
        python update_metadata.py --library "Movies" --poster
    * Change the art for an entire library:
        python update_metadata.py --library "Movies" --art
    * Change the posters and art for an entire library:
        python update_metadata.py --library "Movies" --poster --art
    * Change the poster for a specific item:
        python update_metadata.py --rating_key 1234 --poster
    * Change the art for a specific item:
        python update_metadata.py --rating_key 1234 --art
    * Change the poster and art for a specific item:
        python update_metadata.py --rating_key 1234 --poster --art
    * By default locked posters are skipped. To update locked posters:
        python update_metadata.py --library "Movies" --include_locked --poster --art
    * To override the preferred provider:
        python update_metadata.py --library "Movies" --art --art_provider "fanarttv"
    * Change the logo for a specific item:
        python update_metadata.py --rating_key 1234 --logo
    * Change the metadata language for non-English media:
        python update_metadata.py --rating_key 1234 --language
    * Set the sort title without the leading article for French metadata:
        python update_metadata.py --rating_key 1234 --sort_title
    * Send a recently added notification through another notifier once done
      (requires --rating_key, and the notifier must not be this script):
        python update_metadata.py --rating_key 1234 --notify 2
Tautulli script trigger:
    * Notify on recently added
Tautulli script conditions:
    * Filter which media to select the poster. Examples:
        [ Media Type | is | movie ]
Tautulli script arguments:
    * Recently Added:
        --rating_key {rating_key} --poster --art --logo --language --sort_title --notify <notifier_id>
'''

import argparse
import os
import time
from collections import namedtuple
from urllib.parse import unquote
import requests
import plexapi.base
from plexapi.server import PlexServer
plexapi.base.USER_DONT_RELOAD_FOR_KEYS.add('fields')


def read_tmdb_api_key():
    key_file = os.getenv('TMDB_API_KEY_FILE')
    if key_file:
        with open(key_file) as f:
            return f.read().strip()
    return os.getenv('TMDB_API_KEY', '')


# Poster and art providers to replace
REPLACE_PROVIDERS = ['gracenote', 'plex', None]

# Preferred poster and art provider to use (Note not all providers are availble for all items)
# Possible options: tmdb, tvdb, imdb, fanarttv, gracenote, plex
PREFERRED_POSTER_PROVIDER = 'tmdb'
PREFERRED_ART_PROVIDER = 'tmdb'

# Original language for which the metadata language is left at the library default
DEFAULT_ORIGINAL_LANGUAGE = 'en'
# Metadata language to set for media with a different original language
METADATA_LANGUAGE_OVERRIDE = 'fr-FR'
# Logo language to prefer for media with a non-default original language (ISO 639-1)
LOGO_LANGUAGE_OVERRIDE = 'fr'

# Leading articles to strip from French titles to build the sort title
FRENCH_SORT_ARTICLES = ('le ', 'la ', 'les ', "l'", 'l\u2019', 'un ', 'une ', 'des ')

TMDB_API_URL = 'https://api.themoviedb.org/3'
TMDB_IMAGE_URL = 'https://image.tmdb.org/t/p/original'


# ## OVERRIDES - ONLY EDIT IF RUNNING SCRIPT WITHOUT TAUTULLI ##

PLEX_URL = ''
PLEX_TOKEN = ''
TMDB_API_KEY = ''

# Environmental Variables
PLEX_URL = PLEX_URL or os.getenv('PLEX_URL', PLEX_URL)
PLEX_TOKEN = PLEX_TOKEN or os.getenv('PLEX_TOKEN', PLEX_TOKEN)
TMDB_API_KEY = TMDB_API_KEY or read_tmdb_api_key()
# Provided by Tautulli when running as a notification script
TAUTULLI_URL = os.getenv('TAUTULLI_URL', '')
TAUTULLI_APIKEY = os.getenv('TAUTULLI_APIKEY', '')

TmdbInfo = namedtuple('TmdbInfo', 'original_language poster_path backdrop_path logo_path')
# Returned when TMDB cannot be queried, so callers never have to check for None
NO_TMDB_INFO = TmdbInfo(None, None, None, None)


def get_tmdb_info(item):
    '''Returns the original language, the primary poster path (in the original
    language), the primary backdrop path and the logo path for an item, using
    the TMDB API.'''
    if not TMDB_API_KEY:
        print(f"  - WARNING: No TMDB API key configured. Skipping TMDB lookup for {item.title}.")
        return NO_TMDB_INFO

    tmdb_id = next((guid.id.split('://')[1] for guid in item.guids if guid.id.startswith('tmdb://')), None)
    if tmdb_id is None:
        print(f"  - WARNING: No TMDB guid found for {item.title}.")
        return NO_TMDB_INFO

    endpoint = 'movie' if item.type == 'movie' else 'tv'
    url = f"{TMDB_API_URL}/{endpoint}/{tmdb_id}"

    try:
        details = requests.get(url, params={'api_key': TMDB_API_KEY}, timeout=30)
        details.raise_for_status()
        details = details.json()

        original_language = details.get('original_language')
        poster_path = details.get('poster_path')
        # The backdrop from the base details is the TMDB primary background
        backdrop_path = details.get('backdrop_path')

        if original_language:
            # The details endpoint with a language parameter returns the primary poster for that language
            localized = requests.get(url, params={'api_key': TMDB_API_KEY, 'language': original_language}, timeout=30)
            localized.raise_for_status()
            poster_path = localized.json().get('poster_path') or poster_path

        logo_path = get_tmdb_logo_path(url, original_language)
    except requests.RequestException as e:
        print(f"  - WARNING: TMDB API request failed for {item.title}: {e}")
        return NO_TMDB_INFO

    return TmdbInfo(original_language, poster_path, backdrop_path, logo_path)


def get_tmdb_logo_path(url, original_language):
    '''Returns the primary TMDB logo path: English for English media, otherwise
    French with a fallback to the original language.'''
    if original_language is None:
        return None

    if original_language == DEFAULT_ORIGINAL_LANGUAGE:
        languages = [DEFAULT_ORIGINAL_LANGUAGE]
    else:
        languages = [LOGO_LANGUAGE_OVERRIDE, original_language]

    images = requests.get(
        f"{url}/images",
        params={'api_key': TMDB_API_KEY, 'include_image_language': ','.join(languages)},
        timeout=30
    )
    images.raise_for_status()
    logos = images.json().get('logos', [])

    for language in languages:
        # Logos are sorted by votes, the first match is the primary one for that language
        logo = next((l for l in logos if l.get('iso_639_1') == language), None)
        if logo:
            return logo['file_path']
    return None


def process_library(library, opts):
    for item in library.all(includeGuids=False):
        # Only reload for fields
        item.reload(**{k: 0 for k, v in item._INCLUDES.items()})
        process_item(item, opts)


def process_item(item, opts):
    print(f"{item.title} ({item.year})")

    needs_tmdb = opts.poster or opts.art or opts.logo or opts.language or opts.sort_title
    tmdb = get_tmdb_info(item) if needs_tmdb else NO_TMDB_INFO

    if opts.poster:
        select_poster(item, opts, tmdb.poster_path)
    if opts.art:
        select_art(item, opts, tmdb.backdrop_path)
    if opts.logo:
        select_logo(item, opts, tmdb.logo_path)
    # After the artwork so the metadata refresh cannot revert the locked images
    if opts.language and update_metadata_language(item, tmdb.original_language):
        # The refresh is asynchronous, later steps must see the new metadata
        if opts.sort_title or opts.notify:
            wait_for_metadata_refresh(item)
    if opts.sort_title:
        update_sort_title(item, opts, tmdb.original_language)
    # Last so the notification carries the updated metadata
    if opts.notify:
        send_recently_added_notification(item, opts.notify)


def find_tmdb_image(images, tmdb_path):
    '''Finds a Plex image choice matching a TMDB file path. The TMDB filename
    can appear URL-encoded in the thumb, ratingKey or key depending on the agent,
    so the comparison is done on the URL-decoded fields without the extension.'''
    stem = tmdb_path.rsplit('/', 1)[-1].rsplit('.', 1)[0]
    for image in images:
        fields = f"{image.thumb or ''} {image.ratingKey or ''} {image.key or ''}"
        if stem in unquote(fields):
            return image
    return None


def apply_tmdb_image(item, images, tmdb_path, kind, upload, lock):
    '''Selects the TMDB image among the Plex choices, uploading it when Plex
    exposes no matching source URL.'''
    match = find_tmdb_image(images, tmdb_path)
    if match:
        match.select()  # selecting an image automatically locks the field
        print(f"  - Selected and locked TMDB {kind} for {item.title}.")
    else:
        upload(url=f"{TMDB_IMAGE_URL}{tmdb_path}")
        lock()
        print(f"  - Uploaded and locked TMDB {kind} for {item.title}.")


def select_provider_image(item, images, provider, kind, lock):
    '''Fallback used when TMDB is unavailable: keeps the current image unless it
    comes from a provider we want to replace.'''
    selected = next((i for i in images if i.selected), None)
    if selected is not None and selected.provider not in REPLACE_PROVIDERS:
        lock()
        print(f"  - Locked {selected.provider} {kind} for {item.title}.")
        return

    chosen = next((i for i in images if i.provider == provider), images[0])
    chosen.select()  # selecting an image automatically locks the field
    print(f"  - Selected and locked {chosen.provider} {kind} for {item.title}.")


def send_recently_added_notification(item, notifier_id):
    '''Triggers a Tautulli recently added notification through the given notifier,
    after the metadata has been updated.'''
    print("  Sending Tautulli notification...")

    if not TAUTULLI_URL or not TAUTULLI_APIKEY:
        print("  - WARNING: TAUTULLI_URL or TAUTULLI_APIKEY not available. Skipping notification.")
        return

    try:
        response = requests.get(
            f"{TAUTULLI_URL}/api/v2",
            params={
                'apikey': TAUTULLI_APIKEY,
                'cmd': 'notify_recently_added',
                'rating_key': item.ratingKey,
                'notifier_id': notifier_id,
            },
            timeout=30
        )
        response.raise_for_status()
        # Tautulli reports command failures in the payload with a 200 status
        result = response.json().get('response', {})
    except (requests.RequestException, ValueError) as e:
        print(f"  - WARNING: Tautulli notification failed for {item.title}: {e}")
        return

    if result.get('result') != 'success':
        print(f"  - WARNING: Tautulli notification failed for {item.title}: {result.get('message')}")
        return

    print(f"  - Triggered recently added notification (notifier_id {notifier_id}) for {item.title}.")


def update_metadata_language(item, original_language):
    '''Returns True if the metadata language was changed and a refresh was triggered.'''
    print("  Checking metadata language...")

    if original_language is None:
        print(f"  - WARNING: Unknown original language for {item.title}. Skipping.")
        return False

    if original_language == DEFAULT_ORIGINAL_LANGUAGE:
        print(f"  - Original language is '{original_language}' for {item.title}. Keeping default metadata language.")
        return False

    current = next((s.value for s in item.preferences() if s.id == 'languageOverride'), None)
    if current == METADATA_LANGUAGE_OVERRIDE:
        print(f"  - Metadata language is already '{METADATA_LANGUAGE_OVERRIDE}' for {item.title}.")
        return False

    item.editAdvanced(languageOverride=METADATA_LANGUAGE_OVERRIDE)
    item.refresh()
    print(f"  - Original language is '{original_language}' for {item.title}. "
          f"Set metadata language to '{METADATA_LANGUAGE_OVERRIDE}' and refreshed metadata.")
    return True


def wait_for_metadata_refresh(item, timeout=30):
    '''Best effort wait for the asynchronous refresh, detected through a title change.'''
    old_title = item.title
    deadline = time.time() + timeout
    while time.time() < deadline:
        time.sleep(2)
        item.reload(**{k: 0 for k, v in item._INCLUDES.items()})
        if item.title != old_title:
            return


def strip_french_article(title):
    lower = title.lower()
    for article in FRENCH_SORT_ARTICLES:
        if lower.startswith(article):
            return title[len(article):].lstrip()
    return None


def update_sort_title(item, opts, original_language):
    print("  Checking sort title...")

    if original_language is None or original_language == DEFAULT_ORIGINAL_LANGUAGE:
        print(f"  - Default metadata language for {item.title}. Keeping default sort title.")
        return

    if item.isLocked('titleSort') and not opts.include_locked:
        print(f"  - Locked sort title for {item.title}. Skipping.")
        return

    sort_title = strip_french_article(item.title)
    if sort_title is None:
        print(f"  - No leading French article in '{item.title}'. Keeping default sort title.")
        return

    if item.titleSort == sort_title:
        print(f"  - Sort title is already '{sort_title}' for {item.title}.")
        return

    item.editSortTitle(sort_title, locked=True)
    print(f"  - Set and locked sort title '{sort_title}' for {item.title}.")


def select_poster(item, opts, tmdb_poster_path):
    print("  Checking poster...")

    if item.isLocked('thumb') and not opts.include_locked:  # PlexAPI 4.5.10
        print(f"  - Locked poster for {item.title}. Skipping.")
        return

    posters = item.posters()
    if not posters:
        print(f"  - WARNING: No available posters for {item.title}.")
        return

    if tmdb_poster_path:
        apply_tmdb_image(item, posters, tmdb_poster_path, 'poster', item.uploadPoster, item.lockPoster)
    else:
        select_provider_image(item, posters, opts.poster_provider, 'poster', item.lockPoster)


def select_art(item, opts, tmdb_art_path):
    print("  Checking art...")

    if item.isLocked('art') and not opts.include_locked:  # PlexAPI 4.5.10
        print(f"  - Locked art for {item.title}. Skipping.")
        return

    arts = item.arts()
    if not arts:
        print(f"  - WARNING: No available art for {item.title}.")
        return

    if tmdb_art_path:
        apply_tmdb_image(item, arts, tmdb_art_path, 'art', item.uploadArt, item.lockArt)
    else:
        select_provider_image(item, arts, opts.art_provider, 'art', item.lockArt)


def select_logo(item, opts, tmdb_logo_path):
    print("  Checking logo...")

    if not hasattr(item, 'logos'):
        print("  - WARNING: Logos are not supported by this PlexAPI version. Skipping.")
        return

    if item.isLocked('clearLogo') and not opts.include_locked:
        print(f"  - Locked logo for {item.title}. Skipping.")
        return

    if not tmdb_logo_path:
        print(f"  - WARNING: No TMDB logo found for {item.title}. Skipping.")
        return

    apply_tmdb_image(item, item.logos(), tmdb_logo_path, 'logo', item.uploadLogo, item.lockLogo)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--rating_key', type=int)
    parser.add_argument('--library')
    parser.add_argument('--include_locked', action='store_true')
    parser.add_argument('--poster', action='store_true')
    parser.add_argument('--poster_provider', default=PREFERRED_POSTER_PROVIDER)
    parser.add_argument('--art', action='store_true')
    parser.add_argument('--art_provider', default=PREFERRED_ART_PROVIDER)
    parser.add_argument('--logo', action='store_true')
    parser.add_argument('--language', action='store_true')
    parser.add_argument('--sort_title', action='store_true')
    parser.add_argument('--notify', type=int, metavar='NOTIFIER_ID')
    opts = parser.parse_args()

    # One notification per library item would duplicate the Tautulli grouping
    if opts.notify and not opts.rating_key:
        parser.error('--notify requires --rating_key')

    plex = PlexServer(PLEX_URL, PLEX_TOKEN)

    if opts.rating_key:
        process_item(plex.fetchItem(opts.rating_key), opts)
    elif opts.library:
        process_library(plex.library.section(opts.library), opts)
    else:
        parser.error('either --rating_key or --library is required')
