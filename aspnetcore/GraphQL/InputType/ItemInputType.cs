using rssnews.Models;

namespace rssnews.GraphQL.InputType
{
    // เปลี่ยนจาก InputObjectType<Item> เป็น InputObjectType<ItemInput>
    public class ItemInputType : InputObjectType<ItemInput>
    {
        protected override void Configure(IInputObjectTypeDescriptor<ItemInput> descriptor)
        {
            descriptor.Name("ItemInput");
            // ใช้ property ของ ItemInput แทน Item
            descriptor.Field(i => i.Title).Type<NonNullType<StringType>>();
            descriptor.Field(i => i.Link).Type<NonNullType<StringType>>();
            descriptor.Field(i => i.Description).Type<NonNullType<StringType>>();
            descriptor.Field(i => i.PublishedDate).Type<NonNullType<DateTimeType>>().Name("publishedDate");
            descriptor.Field(i => i.CategoryId).Type<NonNullType<IntType>>().Name("categoryId"); // ใช้ CategoryId ของ ItemInput
            descriptor.Field(i => i.AuthorId).Type<NonNullType<StringType>>().Name("authorId"); // ใช้ AuthorId ของ ItemInput
        }
    }
}