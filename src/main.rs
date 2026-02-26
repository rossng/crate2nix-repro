fn main() {
    let hash = nix_base32::to_nix_base32(&[0x01, 0x02, 0x03]);
    println!("nix base32: {hash}");
}
