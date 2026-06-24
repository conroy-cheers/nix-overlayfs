#include <filesystem>
#include <fstream>
#include <iostream>
#include <map>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace fs = std::filesystem;

namespace {

struct Registry {
    std::string version;
    std::string location;
    std::string arch;
    std::map<std::string, std::map<std::string, std::string>> keys;
};

bool starts_with(std::string_view value, std::string_view prefix)
{
    return value.size() >= prefix.size() && value.substr(0, prefix.size()) == prefix;
}

bool blank(std::string_view line)
{
    for (const char c : line) {
        if (c != ' ' && c != '\t' && c != '\r') return false;
    }
    return true;
}

void strip_cr(std::string &line)
{
    if (!line.empty() && line.back() == '\r') line.pop_back();
}

std::optional<Registry> parse_registry(const fs::path &path, std::string &error)
{
    std::ifstream in(path);
    if (!in) {
        error = "failed to open";
        return std::nullopt;
    }

    Registry registry;
    std::string section;
    std::string line;
    std::string pending_name;
    std::string pending_value;
    bool have_pending = false;

    auto flush_pending = [&]() {
        if (have_pending) {
            registry.keys[section][pending_name] = pending_value;
            pending_name.clear();
            pending_value.clear();
            have_pending = false;
        }
    };

    size_t line_no = 0;
    while (std::getline(in, line)) {
        ++line_no;
        strip_cr(line);

        if (have_pending) {
            pending_value += "\n";
            pending_value += line;
            if (!line.empty() && line.back() == '\\') {
                continue;
            }
            flush_pending();
            continue;
        }

        if (starts_with(line, "WINE REGISTRY Version ")) {
            registry.version = line.substr(std::string("WINE REGISTRY Version ").size());
            continue;
        }

        if (starts_with(line, ";; All keys relative to ")) {
            registry.location = line.substr(std::string(";; All keys relative to ").size());
            continue;
        }

        if (starts_with(line, "#arch=")) {
            registry.arch = line.substr(std::string("#arch=").size());
            continue;
        }

        if (line.empty() || blank(line)) {
            continue;
        }

        if (starts_with(line, "#")) {
            continue;
        }

        if (line.front() == '[') {
            const auto close = line.find(']');
            if (close == std::string::npos) {
                error = "malformed section header at line " + std::to_string(line_no);
                return std::nullopt;
            }
            section = line.substr(1, close - 1);
            registry.keys.try_emplace(section);
            continue;
        }

        const auto equals = line.find('=');
        if (equals == std::string::npos || section.empty()) {
            error = "malformed value at line " + std::to_string(line_no);
            return std::nullopt;
        }

        pending_name = line.substr(0, equals);
        pending_value = line.substr(equals + 1);
        if (!pending_value.empty() && pending_value.back() == '\\') {
            have_pending = true;
        } else {
            registry.keys[section][pending_name] = pending_value;
        }
    }

    flush_pending();

    if (registry.version.empty()) registry.version = "2";
    if (registry.arch.empty()) registry.arch = "win64";
    if (registry.location.empty()) {
        error = "missing registry location header";
        return std::nullopt;
    }

    return registry;
}

bool write_registry(const fs::path &path, const Registry &registry)
{
    std::ofstream out(path);
    if (!out) return false;

    out << "WINE REGISTRY Version " << registry.version << '\n';
    out << ";; All keys relative to " << registry.location << "\n\n";
    out << "#arch=" << registry.arch << "\n\n";

    bool first_section = true;
    for (const auto &[section, values] : registry.keys) {
        if (!first_section) out << '\n';
        first_section = false;

        out << '[' << section << "]\n";
        for (const auto &[name, value] : values) {
            out << name << '=' << value << '\n';
        }
    }

    return true;
}

bool merge_one(const fs::path &out_dir, const std::string &reg_name, const std::vector<fs::path> &source_dirs)
{
    Registry merged;
    bool have_registry = false;

    for (const auto &source_dir : source_dirs) {
        const auto source_path = source_dir / reg_name;
        if (!fs::is_regular_file(source_path)) continue;

        std::string error;
        auto parsed = parse_registry(source_path, error);
        if (!parsed) {
            std::cerr << "warning: failed to parse registry layer " << source_path << ": " << error << '\n';
            continue;
        }

        if (!have_registry) {
            merged = std::move(*parsed);
            have_registry = true;
            continue;
        }

        merged.version = parsed->version;
        merged.location = parsed->location;
        merged.arch = parsed->arch;
        for (auto &[section, values] : parsed->keys) {
            auto &merged_values = merged.keys[section];
            for (auto &[name, value] : values) {
                merged_values[name] = value;
            }
        }
    }

    if (!have_registry) return true;

    fs::create_directories(out_dir);
    const auto out_path = out_dir / reg_name;
    if (!write_registry(out_path, merged)) {
        std::cerr << "error: failed to write " << out_path << '\n';
        return false;
    }

    return true;
}

} // namespace

int main(int argc, char **argv)
{
    if (argc < 3) {
        std::cerr << "usage: merge-wine-registries OUT_DIR SOURCE_DIR...\n";
        return 2;
    }

    const fs::path out_dir = argv[1];
    std::vector<fs::path> source_dirs;
    for (int i = 2; i < argc; ++i) {
        source_dirs.emplace_back(argv[i]);
    }

    for (const std::string reg_name : {"system.reg", "user.reg", "userdef.reg"}) {
        if (!merge_one(out_dir, reg_name, source_dirs)) {
            return 1;
        }
    }

    return 0;
}
