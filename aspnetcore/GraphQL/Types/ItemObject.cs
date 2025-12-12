using rssnews.GraphQL.Repository;
using rssnews.Models;

namespace rssnews.GraphQL.Types
{
    public sealed class ItemObject : ObjectType<Item>
    {
        protected override void Configure(IObjectTypeDescriptor<Item> descriptor)
        {
            descriptor.Name("ItemObject"); // กำหนดชื่อของ GraphQL Type, ควรเป็นชื่อที่ชัดเจน

            descriptor.Field(it => it.ItemID)
                .Type<NonNullType<StringType>>() // ระบุ HotChocolate Type
                .Description("The ID of the RSS item.")
                .Name("itemID");

            descriptor.Field(it => it.Title)
                .Type<NonNullType<StringType>>()
                .Description("The title of the RSS item.");

            descriptor.Field(it => it.Link)
                .Type<NonNullType<StringType>>()
                .Description("The link to the RSS item content.");

            descriptor.Field(it => it.Description)
                .Type<NonNullType<StringType>>()
                .Description("The description of the RSS item.");

            // ใช้ HotChocolate's DateTimeType
            descriptor.Field(it => it.PublishedDate)
                .Type<NonNullType<DateTimeType>>() // HotChocolate มี DateTimeType ของตัวเอง
                .Description("The publication date of the RSS item.")
                .Name("publishedDate");

            descriptor.Field(it => it.CategoryID)
                .Type<NonNullType<IntType>>()
                .Description("The ID of the category.")
                .Name("categoryID");

            descriptor.Field(it => it.AuthorID)
                .Type<NonNullType<StringType>>()
                .Description("The ID of the author.")
                .Name("authorBuasriID");

            descriptor.Field("category")
                .Type<ObjectType<CategoryObject>>()
                .ResolveWith<ItemResolvers>(t => t.GetCategory(default!, default!))
                .Description("The category of the RSS item.");

            descriptor.Field("author")
                .Type<ObjectType<AuthorObject>>()
                .ResolveWith<ItemResolvers>(t => t.GetAuthor(default!, default!))
                .Description("The author of the RSS item.");
        }
    }
    public class ItemResolvers
    {
        public async Task<Category?> GetCategory([Parent] Item item, [Service] ICategoryService categoryService)
        {
            return await categoryService.GetCategoryById(item.CategoryID);
        }

        public async Task<Author?> GetAuthor([Parent] Item item, [Service] IAuthorService authorService)
        {
            return await authorService.GetAuthorById(item.AuthorID);
        }
    }
}
