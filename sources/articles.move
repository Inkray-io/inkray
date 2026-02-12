module contracts::articles;

use contracts::inkray_events;
use contracts::publication::{Self, Publication, PublicationOwnerCap};
use contracts::vault::{Self, Access, PublicationVault};
use std::string::{Self, String};

const E_NOT_AUTHORIZED: u64 = 0;
const E_INVALID_PUBLICATION: u64 = 1;
const E_INVALID_VAULT: u64 = 2;
const E_ARTICLE_NOT_FROM_PUBLICATION: u64 = 3;
const E_VAULT_MISMATCH: u64 = 4;

public struct Article has key, store {
    id: UID,
    gating: Access,
    body_blob_id: ID,
    title: String,
    slug: String,
    publication_id: ID,
    vault_id: ID,
    author: address,
}

public struct PostArticleCap has key, store {
    id: UID,
}

fun init(ctx: &mut TxContext) {
    let post_cap = PostArticleCap { id: object::new(ctx) };
    transfer::transfer(post_cap, tx_context::sender(ctx));
}

public fun post(
    publication: &Publication,
    vault: &mut PublicationVault,
    title: String,
    gating: Access,
    body_blob: walrus::blob::Blob,
    ctx: &mut TxContext,
): Article {
    let author = tx_context::sender(ctx);
    assert!(publication::is_contributor(publication, author), E_NOT_AUTHORIZED);
    post_internal(publication, vault, title, gating, body_blob, author, ctx)
}

public fun post_as_owner(
    owner_cap: &PublicationOwnerCap,
    publication: &Publication,
    vault: &mut PublicationVault,
    title: String,
    gating: Access,
    body_blob: walrus::blob::Blob,
    ctx: &mut TxContext,
): Article {
    assert!(publication::verify_owner_cap(owner_cap, publication), E_NOT_AUTHORIZED);
    let author = tx_context::sender(ctx);
    post_internal(publication, vault, title, gating, body_blob, author, ctx)
}

public fun post_with_cap(
    _cap: &PostArticleCap,
    publication: &Publication,
    vault: &mut PublicationVault,
    title: String,
    gating: Access,
    body_blob: walrus::blob::Blob,
    author: address,
    ctx: &mut TxContext,
): Article {
    post_internal(publication, vault, title, gating, body_blob, author, ctx)
}

fun post_internal(
    publication: &Publication,
    vault: &mut PublicationVault,
    title: String,
    gating: Access,
    body_blob: walrus::blob::Blob,
    author: address,
    ctx: &mut TxContext,
): Article {
    let publication_id = publication::get_publication_object_id(publication);
    let vault_id = vault::get_vault_id(vault);
    assert!(publication::get_vault_id(publication) == vault_id, E_INVALID_VAULT);

    let article_id = object::new(ctx);
    let article_object_id = article_id.to_inner();
    let slug = generate_slug_from_title(title, &article_id);
    let body_blob_id = vault::get_blob_object_id(&body_blob);
    let body_content_id = vault::get_blob_content_id(&body_blob);
    publication::store_blob_in_vault(publication, vault, body_blob, ctx);

    let article = Article {
        id: article_id, gating, body_blob_id, title, slug,
        publication_id, vault_id, author,
    };

    inkray_events::emit_article_posted(
        publication_id, vault_id, article_object_id, author,
        title, slug, access_to_u8(&gating), body_content_id, body_blob_id,
    );

    article
}

public fun update_article(
    owner_cap: &PublicationOwnerCap,
    publication: &Publication,
    article: &mut Article,
    new_title: String,
    _ctx: &TxContext,
) {
    assert!(publication::verify_owner_cap(owner_cap, publication), E_NOT_AUTHORIZED);
    assert!(
        article.publication_id == publication::get_publication_object_id(publication),
        E_INVALID_PUBLICATION,
    );
    assert!(article.vault_id == publication::get_vault_id(publication), E_INVALID_VAULT);
    article.title = new_title;
    article.slug = generate_slug_from_title(new_title, &article.id);
}

public fun delete_article(
    owner_cap: &PublicationOwnerCap,
    publication: &Publication,
    vault: &mut PublicationVault,
    article: Article,
    system: &mut walrus::system::System,
    ctx: &mut TxContext,
) {
    assert!(publication::verify_owner_cap(owner_cap, publication), E_NOT_AUTHORIZED);
    assert!(
        article.publication_id == publication::get_publication_object_id(publication),
        E_ARTICLE_NOT_FROM_PUBLICATION,
    );
    assert!(article.vault_id == publication::get_vault_id(publication), E_VAULT_MISMATCH);
    assert!(vault::get_vault_id(vault) == article.vault_id, E_VAULT_MISMATCH);

    let Article { id, gating: _, body_blob_id, title, slug, publication_id, vault_id, author: _ } = article;
    let article_id = id.to_inner();
    let blob = publication::remove_blob_from_vault(publication, vault, body_blob_id, ctx);
    let storage = walrus::system::delete_blob(system, blob);
    walrus::storage_resource::destroy(storage);
    object::delete(id);

    inkray_events::emit_article_deleted(
        publication_id, vault_id, article_id, tx_context::sender(ctx),
        title, slug, body_blob_id,
    );
}

// === Slug Generation ===

public fun generate_slug_from_title(title: String, article_uid: &UID): String {
    let cleaned_title = clean_title_string(title);
    let unique_suffix = uid_to_short_hex(article_uid);
    let mut slug = cleaned_title;
    if (string::length(&slug) > 0) {
        string::append(&mut slug, string::utf8(b"-"));
    };
    string::append(&mut slug, unique_suffix);
    slug
}

fun clean_title_string(title: String): String {
    let title_bytes = string::as_bytes(&title);
    let mut result_bytes = vector::empty<u8>();
    let mut i = 0;
    let len = vector::length(title_bytes);
    let mut last_was_hyphen = false;

    while (i < len) {
        let byte = *vector::borrow(title_bytes, i);
        let processed_byte = if (byte >= 65 && byte <= 90) {
            byte + 32
        } else if (byte == 32) {
            45
        } else if (is_valid_slug_char(byte)) {
            byte
        } else {
            0
        };

        if (processed_byte != 0) {
            let is_hyphen = (processed_byte == 45);
            if (!is_hyphen || !last_was_hyphen) {
                vector::push_back(&mut result_bytes, processed_byte);
            };
            last_was_hyphen = is_hyphen;
        };
        i = i + 1;
    };

    if (!vector::is_empty(&result_bytes)) {
        let last_idx = vector::length(&result_bytes) - 1;
        if (*vector::borrow(&result_bytes, last_idx) == 45) {
            vector::pop_back(&mut result_bytes);
        };
    };
    if (!vector::is_empty(&result_bytes)) {
        if (*vector::borrow(&result_bytes, 0) == 45) {
            vector::remove(&mut result_bytes, 0);
        };
    };

    string::utf8(result_bytes)
}

fun is_valid_slug_char(byte: u8): bool {
    (byte >= 97 && byte <= 122) || (byte >= 48 && byte <= 57) || (byte == 45)
}

fun uid_to_short_hex(uid: &UID): String {
    let uid_bytes = object::uid_to_bytes(uid);
    let mut hex_bytes = vector::empty<u8>();
    let mut i = 0;
    while (i < 4 && i < vector::length(&uid_bytes)) {
        let byte = *vector::borrow(&uid_bytes, i);
        vector::push_back(&mut hex_bytes, nibble_to_hex_char(byte / 16));
        vector::push_back(&mut hex_bytes, nibble_to_hex_char(byte % 16));
        i = i + 1;
    };
    string::utf8(hex_bytes)
}

fun nibble_to_hex_char(nibble: u8): u8 {
    if (nibble < 10) { 48 + nibble } else { 97 + nibble - 10 }
}

fun access_to_u8(access: &Access): u8 {
    if (vault::is_free(access)) { 0 } else { 1 }
}

// === View Functions ===

public fun get_article_id(article: &Article): ID {
    article.id.to_inner()
}

public fun is_free_content(article: &Article): bool {
    vault::is_free(&article.gating)
}

public fun get_article_info(article: &Article): (String, String, ID, ID, address, u8) {
    (
        article.title, article.slug, article.publication_id,
        article.vault_id, article.author, access_to_u8(&article.gating),
    )
}

public fun get_gating(article: &Article): &Access {
    &article.gating
}

public fun get_body_blob_id(article: &Article): ID {
    article.body_blob_id
}

public fun get_publication_id(article: &Article): ID {
    article.publication_id
}

public fun get_vault_id(article: &Article): ID {
    article.vault_id
}

public fun get_author(article: &Article): address {
    article.author
}

public fun get_title(article: &Article): String {
    article.title
}

public fun get_slug(article: &Article): String {
    article.slug
}

public fun preview_slug_from_title(title: String, ctx: &mut TxContext): String {
    let temp_uid = object::new(ctx);
    let slug = generate_slug_from_title(title, &temp_uid);
    object::delete(temp_uid);
    slug
}
